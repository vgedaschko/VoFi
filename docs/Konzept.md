# Konzept: VoFi-Werkzeug für Neubau und energetische Sanierung von Wohngebäuden

| | |
|---|---|
| **Dokument** | `docs/Konzept.md`: zentrales Konzept für Auftraggeber, Fachanwender und Entwicklung |
| **Stand** | 25.10.2026 (Rechts-, Förder- und Datenstand der Recherche-Memos; KfW-Konditionen vom 22.10.2026) |
| **Status** | Entwurf zur Entscheidung durch den Auftraggeber. Er beantwortet den ersten Teil des Auftrags: erst klären, *wie* das Werkzeug gebaut wird und *was* dafür nötig ist, dann bauen. |
| **Grundlage** | Recherche-Memos 01–07 in `docs/recherche/` (Verzeichnis in Anhang B) |
| **Technische Spezifikation** | `docs/spec/00_kernvertraege.md` (verbindliche Kernverträge, in Arbeit). Dieses Konzept regelt Ziele, Fachlogik und Umfang. Datenstrukturen, Schlüssel und Schnittstellen regelt die Spezifikation und werden hier nicht wiederholt. |
| **Review** | Review-Runde 1 (Praxissicht und Vollständigkeit aus Laiensicht) ist eingearbeitet; Befunde und Entscheidungen stehen im Anhang: Review-Protokoll. |
| **Hinweis** | Werkzeug und Dokument dienen der Entscheidungsunterstützung. Sie sind keine Rechts-, Steuer-, Förder- oder Anlageberatung. |

**Lesehilfe.** Für Geschäftsführung, Vorstand und Controlling sind die Kapitel 0, 1, 2, 7, 10 und 11 gedacht. Wer fachlich plant, liest zusätzlich 3, 4, 6 und 9. Für die Entwicklung sind 5 und 8 bestimmt, die Details stehen in der Spezifikation.

**Kennzeichnungen.** „(Sek.)“ heißt: Die Angabe ist nur über Sekundärquellen belegt und muss vor der Übernahme in die
Parameterbibliothek am Primärtext geprüft werden. „(Abl.)“ steht für eine eigene Ableitung der Recherche, „(anhängig)“ für ein nicht abgeschlossenes
Gesetzgebungsverfahren. Zahlen stehen im deutschen Format (Tausenderpunkt, Dezimalkomma).

---

## 0. Management Summary

**Was das Werkzeug leistet.** `vofi` ist ein R-Paket. Es stellt für Neubau und energetische Sanierung von Wohngebäuden
in Deutschland einen **Vollständigen Finanzplan (VoFi nach Grob)** auf. Jede Zahlung erscheint je Periode in einer
prüfbaren Tabelle: Investition, Förderung, Mieten oder Energiekosten, Bewirtschaftung, Kredite, Zinsen und
Zwischenanlage. Defizite und Überschüsse gleicht das Werkzeug nach festen Regeln über Kontokorrent bzw. Geldanlage aus. Das Ergebnis
ist das **Vermögen am Ende des Betrachtungszeitraums (Endwert)**, verglichen mit einer Referenzalternative. Eine
**Monte-Carlo-Simulation** rechnet denselben Finanzplan für 1.000 bis 10.000 mögliche Zukünfte durch (Zinsen, Energie-
und CO₂-Preise, Baukosten, Förderzusage, Einsparrealisierung …) und zeigt, wie robust eine Entscheidung ist.

**Für wen.** Wohnungsunternehmen (kommunal, genossenschaftlich, privatwirtschaftlich) nutzen den **Fachmodus**
(VoFi-Tabelle, EK-Rendite, DSCR, Warmmiete je m²). Selbstnutzer und private Kleinvermieter nutzen den **Haushaltsmodus**
(monatliche Belastung, Ersparnis pro Monat, Amortisationsjahr, Bandbreite in Worten). Beide Modi verwenden dieselbe Rechenmaschine.

**Typische Fragen.** Lohnt sich EH 70 gegenüber der Ohnehin-Instandsetzung? Wärmepumpe jetzt oder Gaskessel
behalten? Welche Miete braucht ein Neubau, um sich zu tragen? Was passiert, wenn der Zins nach der Zinsbindung bei 6 % liegt
oder die Förderung ausläuft? Wie verändert sich die Warmmiete der Mieter?

**Zentrale Designentscheidungen (Details in Kapitel 11).**

- **Rechenkern VoFi statt Kapitalwert.** Soll- und Habenzins dürfen sich unterscheiden. Förderkredite, Tilgungszuschüsse und
  Anschlussfinanzierung werden vertragsgenau abgebildet, und Liquiditätsengpässe werden sichtbar. **Hauptkennzahl ist die
  Endwertdifferenz** gegenüber der Referenzalternative (Unterlassung bzw. Ohnehin-Sanierung). Sie wird **immer mit und ohne
  Restwert** ausgewiesen. Bei Bestandsobjekten ist die Referenz stets eine Gebäudevariante (Nichtstun bzw. Ohnehin-Sanierung).
- **Eine Engine für Einzelrechnung und Simulation.** Der deterministische Fall ist der Spezialfall N = 1. Der Prototyp
  rechnet 10.000 Läufe × 83 Perioden in rund 0,3 s.
- **Recht und Förderung sind Daten, kein Code.** Sie stehen in versionierten Bibliotheken mit Quelle, Abrufdatum und Gültigkeit.
  Anhängige Reformen sind Schalter mit der Voreinstellung „aus“. Veraltete Einträge lösen Warnungen aus.
- **Erweiterbarkeit über eine Registry.** Neue Kreditarten, Zahlungsbausteine, Förderprogramme oder Steuermodule kommen
  als neue Datei bzw. als neuer Bibliothekseintrag hinzu, ohne Eingriff in den Kern.
- **Eingabe** als YAML (versionierbar) oder Excel-Vorlage (für die Praxis). **Ausgabe** auf der Konsole, als Excel-Datei und als HTML-Bericht.

**Was v1 enthält.** Ein Gebäude bzw. Projekt mit beliebig vielen Varianten. Neubau und Sanierung, auch stufenweise
(iSFP). Investition nach DIN 276 mit Ohnehin-Anteil, Ersatzinvestitionen, Mietrecht (§§ 558, 559, 559a, 559c, 559e,
559f BGB, Staffel- und Indexmiete, Mietpreisbremse), CO₂-Kostenaufteilung (Stufenmodell und § 5a ab 2028), Energie mit
expliziter CO₂-Preiskomponente, ein generisches Fördermodell mit BEG/KfW-Bibliothek (Stand 10/2026), mehrere Darlehen
mit Zinsbindung und stochastischem Anschlusszins sowie wählbare Restwertverfahren. Hinzu kommen Monte Carlo mit
Korrelationen, Sensitivitäten (Tornado, Zielwertsuche) und ein Variantenvergleich mit gemeinsamen Zufallszahlen. Ausgegeben werden die VoFi-Tabelle,
die Kennzahlen, ein Excel-Export und ein HTML-Bericht im Fach- und im Haushaltsmodus, mit zweistufiger Ampel und druckfähiger Kurzvorlage für Gremien.

**Bewusst nicht in v1.**

| Thema | Warum nicht in v1 | Wann |
|---|---|---|
| **Ertragsteuern** (ESt, KSt, GewSt) | Die Komplexität ist **hoch**. Das liegt nicht an den Formeln, sondern an vier Punkten: (a) der Einordnung jeder Maßnahme als Erhaltungsaufwand oder Herstellungskosten (BMF-Schreiben vom 26.01.2026), (b) Daten außerhalb des Projekts (übriges Einkommen, Verlustvorträge, Organkreis, Status der erweiterten Kürzung), (c) befristeten Normen (degressive AfA und § 7b bis 30.09.2029, § 35c bis 31.12.2029, KSt-Senkung 2028–2032) und (d) mindestens fünf getrennten Steuerregimen. Die **Entscheidungsrelevanz** ist für Selbstnutzer gering, für die meisten Wohnungsunternehmen gering bis mittel (Genossenschaften mit Vermietungsprivileg und Gemeinnützige sind befreit, Kapitalgesellschaften mit erweiterter Kürzung tragen rund 15,8 %), für **privatwirtschaftliche Kapitalgesellschaften ohne erweiterte Kürzung mittel bis groß** (Belastung rund 30 %) und **für private Vermieter hoch**, denn dort kann sich die Rangfolge der Varianten umkehren. | v1: Rechnung vor Steuern. Steuer-Schnittstelle, Steuer-Kennzeichnungen und Anlagenregister sind ab v1 Pflicht, ihre Pflichttests laufen mit einem Test-Steuermodul. Die Zeile „Ertragsteuern“ ist sichtbar und trägt den Vermerk „nicht berücksichtigt“. Ergebnisse von Kleinvermietern und von Kapitalgesellschaften ohne erweiterte Kürzung tragen einen deutlichen Steuerwarnhinweis. Spät in v1 folgt optional ein vereinfachtes Pauschalsteuermodul (standardmäßig aus, für Selbstnutzer und steuerbefreite Rechtsträger gesperrt). § 35c EStG ist schon in v1 als Förderinstrument abgebildet, die Option „Habenzins nach Abgeltungsteuer“ gehört zum Pflichtumfang (Voreinstellung aus). Vollmodul ab v2. |
| Portfolio (mehrere Gebäude, gemeinsame Finanzierung) | Budget- und Finanzierungskopplung über Gebäude hinweg, korrelierte Gebäudeparameter | v2. Das Datenmodell lässt Portfolios bereits zu. |
| Kostenmiete nach II. BV, WEG, gemischte Nutzung | eigene Rechtslogik (Bindungen, Beschlüsse, Vorsteueraufteilung) | v2 |
| Shiny-Oberfläche | Sie hängt von einer stabilen API ab. | v1.1 als Viewer |
| Vollständige Mieter-VoFi, stündliche PV- bzw. WP-Simulation | hoher Aufwand bei geringem Entscheidungsbeitrag | v2 (v1 enthält eine abgeleitete Warmmietensicht) |
| Handelsbilanzielle Sicht (GuV und Bilanz nach HGB: Instandhaltungsaufwand gegenüber aktivierter Modernisierung, Abschreibung, Behandlung von Zuschüssen, Abgang des Restbuchwerts beim Ersatzneubau) | wirkt nicht auf die Zahlungsreihe, wohl aber auf Ausschüttungsfähigkeit, Covenants, Bilanzgewinn und kommunalen Wirtschaftsplan; eigene Rechenlogik (Memo 06, Element 37) | v1.1: indikative Aufteilung „Aufwand / aktivierungsfähig“ je Variante aus den Steuer-Kennzeichnungen mit dem Vermerk „nicht HGB-geprüft“; HGB-Vorschau v2+ |

**Wie die Ergebnisse zu nutzen sind.**

1. **Endwertdifferenz > 0** bedeutet: Unter den getroffenen Annahmen ist die Variante vermögensmäßig besser als die Referenz.
2. **Immer mit und ohne Restwert lesen.** Bei 30 bis 40 Jahren Horizont entscheidet die Restwertannahme oft über das
   Vorzeichen (in Szenario S1 ist die Restwertdifferenz größer als die Netto-Mehrinvestition).
3. **Robustheit statt Punktwert:** Aussagekräftig sind die Wahrscheinlichkeit „besser als die Referenz“, das 5-%-Quantil und die Bandbreite
   in Worten („in 8 von 10 simulierten Zukünften …“).
4. **Treiber prüfen:** Das Tornado-Diagramm nennt die wenigen Annahmen, die das Ergebnis bestimmen. Gerade sie
   verdienen die sorgfältigste Datenbeschaffung.
5. **Basisfall ≠ Erwartungswert:** Der deterministische VoFi und der Median der Simulation weichen systematisch voneinander ab. Das Werkzeug weist beide aus.
6. **Annahmen sind dokumentiert:** Jeder Wert führt seine Herkunft mit (Bibliothek, Datei, Excel-Zelle) und erscheint im
   Annahmenprotokoll. Förderkonditionen sind vor dem Antrag beim Fördergeber zu prüfen.

**Was jetzt vom Auftraggeber gebraucht wird** (vollständige Liste mit Voreinstellungen in Abschnitt 11.3): die Priorität der
Zielgruppen und die Rolle privater Vermieter (davon hängt das Pauschalsteuermodul ab), die Konto- und Schwellenwert-Voreinstellungen je Perspektive,
der Standardhorizont und die Restwertmethode je Anwendungsfall, die Bewertung von Bestandsobjekten (Bestandswert, Bestandsdarlehen), das Betriebsmodell für Haushalte,
die mietrechtlichen Auslegungsfragen, die Lizenz bzw. die Art der Veröffentlichung, die Zuständigkeit für die fachlich-juristische Prüfung und
für die Pflege der Bibliotheken.

---

## 1. Ziel, Nutzergruppen und Fragestellungen

### 1.1 Ziel

Das Werkzeug beantwortet die Frage, **ob und in welcher Ausführung sich ein Neubau oder eine energetische Sanierung
wirtschaftlich lohnt**. Es rechnet aus Sicht des Eigentümers, berücksichtigt Finanzierung, Förderung, Mietrecht und Energiepreisrisiken vollständig und
legt den Rechenweg offen. Es soll so nachvollziehbar sein, dass ein Aufsichtsrat, eine Bank oder eine Förderstelle die
Tabelle prüfen kann, und so verständlich, dass ein Haushalt die Aussage „Sie sparen rund 110 € pro Monat“ richtig einordnet.

### 1.2 Nutzergruppen (Personas aus Memo 07)

| Persona | Typische Entscheidungsfrage | Entscheidungskriterium | Horizont | Modus |
|---|---|---|---|---|
| (a) Controllerin, kommunales Wohnungsunternehmen (5.000–20.000 WE) | EH 70 bzw. EH 55 oder Ohnehin-Instandsetzung? Neubau mit welcher Miete darstellbar? Robustheit gegenüber Zinsen in 10 Jahren? | Differenz-Endwert ≥ 0 bei Habenzins = Zielrendite (z. B. 3,5 %, Voreinstellung A2); das entspricht VoFi-EK-Rendite bzw. bei Bestandsobjekten Rendite der Mehrinvestition ≥ Zielrendite (2.5); Nebenbedingungen Warmmietenneutralität, DSCR ≥ 1,2, Liquidität, CO₂-Pfad | Sanierung 25–30 J., Neubau 40–50 J. | Fach |
| (b) Vorstand/Technik einer Wohnungsgenossenschaft | Heizungstausch Gas → Wärmepumpe (+ PV) kostendeckend bei mitgliederverträglichem Nutzungsentgelt? | Differenz-Endwert ≥ 0 bei Mindestverzinsung (z. B. 2 %), Warmmiete der Mitglieder nicht höher als in der Referenz | 20–30 J. | Fach (zwei Perspektiven: Genossenschaft und Mitglieder) |
| (c) Privater Kleinvermieter (6-WE-MFH) | Womit ersetze ich die Gasheizung? Wie viel darf ich umlegen? Muss ich zuschießen? | kein dauerhaft negativer Cashflow, Amortisation im persönlichen Horizont | 10–20 J. | Haushalt (mit deutlichem Steuerhinweis) |
| (d) Selbstnutzer EFH Baujahr 1975 mit iSFP | Wärmepumpe jetzt? Dämmung zuerst? Stufenweise oder alles auf einmal? Was, wenn die Förderung 2033 endet? | geringere Gesamtkosten bei tragbarer Monatsbelastung, Sicherheit gegen Energiepreise | 15–25 J. | Haushalt |
| (e) Familie, Neubau EFH (KfW 300/297) | Rechnet sich EH 40 mit KfW 300 gegenüber dem gesetzlichen Standard? Monatsrate je Phase? Zinsrisiko 2037? | Belastungsquote ≤ 35–40 %, geringste Gesamtkosten, Robustheit gegen Zinsanstieg | 30–35 J. | Haushalt |

### 1.3 Entscheidungsfragen und Werkzeugfunktionen

| Frage | Antwort des Werkzeugs |
|---|---|
| Ist Variante X besser als die Referenz? | Endwertdifferenz (mit und ohne Restwert), Wahrscheinlichkeit „besser als Referenz“ |
| Welche Ausführung ist die beste? | Variantenvergleich mit Rangfolge auf gemeinsamen Zufallszahlen |
| Ab wann lohnt es sich? | dynamische Amortisation (dauerhaft), ohne Restwert und als Vermögensamortisation mit Restwertpfad; im Haushaltsmodus als Amortisationsjahr |
| Kann ich das finanzieren? | Kontokorrent-Spitzenbedarf, Nachschüsse, Mindestliquidität, DSCR (ab Stabilisierungsjahr), Belastungsquote |
| Welche Miete bzw. welche Förderung brauche ich? | Zielwertsuche (Break-even-Miete, Zielrenditemiete, Liquiditäts- bzw. DSCR-Break-even, kostendeckendes Nutzungsentgelt, warmmietenneutrale Umlage, notwendige Förderung, maximal tragbare Investition) |
| Was passiert, wenn …? | deterministische Szenario-Sets (z. B. „vorsichtig“, „Zinsschock“, „Förderstopp“) und Monte Carlo |
| Was bedeutet es für die Mieter? | Warmmietenpfad je Variante (Nettokaltmiete + Umlage + Heiz- und Warmwasserkosten + sonstige Betriebskosten), als Änderung „vorher/nachher“ und „gegenüber der Referenz“ |
| Woran hängt das Ergebnis? | Tornado, Spider-Plot, globale Sensitivität aus der Simulation |

### 1.4 Zwei Berichtsmodi

| Merkmal | Fachmodus (Wohnungsunternehmen, Genossenschaft) | Haushaltsmodus (Selbstnutzer, Kleinvermieter) |
|---|---|---|
| Ergebnis auf einen Blick | Ampel (zweistufig), Differenz-Endwert mit und ohne Restwert, VoFi-EK-Rendite bzw. Rendite der Mehrinvestition, P(besser), Warmmietenänderung €/m² (vorher/nachher und gegenüber der Referenz), Restriktionen (DSCR, Liquidität, Warmmiete) | Ampel (zweistufig), „Sie sparen / zahlen mehr … € pro Monat“ (erstes volles Nutzungsjahr und Durchschnitt der ersten 10 Jahre), Eigenanteil heute nach Förderung (Einmalbetrag), Summe der Nachschüsse, Amortisationsjahr, Gesamtersparnis nach N Jahren, Bandbreite in Worten |
| Einheiten | € gesamt, je WE und je m² Wohnfläche (und Monat); Kennzahlentabelle je WE und je m² für Investition, Förderung, Mehrinvestition, Endwertdifferenz, Kapitaldienst, Umlage und CO₂-Vermeidungskosten | € pro Monat, gerundet auf 5 bzw. 10 € |
| Zeitverläufe | Vermögen bzw. Kontostand, Cashflow nach Kategorien, DSCR | monatliche Belastung je Jahr, kumulierte Ersparnis |
| Risiko | Verteilung, Fächer, Tornado, Konvergenz, Szenariotabelle | „In X von 10 simulierten Zukünften …“, die drei wichtigsten Einflussgrößen in Worten |
| Kurzvorlage (druckfähig) | Entscheidungsvorlage mit 2–4 Seiten für Aufsichtsrat, Vertreterversammlung oder Bank: Beschlussvorschlag, Investition, Finanzierung und Förderung, Kennzahlen mit und ohne Restwert, Restriktionen, die drei wichtigsten Risiken, Szenariotabelle | Zusammenfassung auf 1–2 Seiten zum Mitnehmen |
| Anhang | vollständige VoFi-Tabellen und Annahmenprotokoll | verkürztes Annahmenprotokoll, VoFi-Tabelle optional |

Die Voreinstellung des Modus folgt aus der Perspektive und lässt sich überschreiben. **Regeln für die Verständlichkeit** (Memo 07 §5.4): Monats- statt
Jahreswerte; Liquidität („Was geht vom Konto ab?“) und Vermögen („Was besitze ich am Ende mehr?“) getrennt zeigen, denn Tilgung ist
Vermögensaufbau und keine Kosten; Bandbreiten in Worten; keine Scheingenauigkeit; Wörter statt Vorzeichen („Sie
sparen 45 €“); nominal mit umschaltbarer Sicht „in heutiger Kaufkraft“; die drei einflussreichsten Annahmen im Fazit nennen.
Die Haushaltskennzahlen (monatliche Belastung, Ersparnis pro Monat, Eigenanteil, Amortisationsjahr) sind in 2.5 definiert.

**Ampelregel (Voreinstellung, konfigurierbar, zweistufig):**

- *Stufe 1, Wirtschaftlichkeit* (Vermögensdifferenz gegenüber der Referenz mit der gewählten Restwertmethode): Grün bedeutet Median > 0 und
  P(besser) ≥ 70 %, Gelb P zwischen 40 % und 70 %, Rot P < 40 %. Hat die Differenz im Basisfall ohne Restwert ein anderes Vorzeichen als mit Restwert,
  ist die Stufe höchstens Gelb, mit dem Hinweis „Ergebnis hängt am Restwert“. Ohne Monte Carlo gilt: Grün, wenn die Differenz im Basisfall und im
  Szenario-Set „vorsichtig“ > 0 ist; Rot, wenn sie in beiden ≤ 0 ist; sonst Gelb. Wurde weder simuliert noch das Szenario-Set „vorsichtig“ gerechnet,
  ist die Ampel höchstens Gelb („keine Robustheitsprüfung“).
- *Stufe 2, Restriktionen* (K.-o.-Kennzeichen je Perspektive): DSCR unter Covenant, Kontokorrent über Limit bzw. Liquiditätsengpass,
  Warmmietenanstieg über Schwelle, Belastungsquote über Schwelle, Nachschuss über Sparfähigkeit. Ist eine Restriktion im Basisfall verletzt oder
  liegt ihre Verletzungswahrscheinlichkeit bei mindestens 30 %, zeigt die Gesamtampel höchstens Gelb. Das Kennzeichen nennt Restriktion, Jahr und Betrag.

Das **Szenario-Set „vorsichtig“** ist ab v1 Bibliotheksstandard: Die fünf einflussreichsten Treiber laut Tornado stehen gleichzeitig auf ihrem für die
Variante ungünstigen P10- bzw. P90-Wert. Weitere Presets („Basis“, „optimistisch“) folgen in v1.1.

---

## 2. Methodik: der VoFi in Kürze

### 2.1 Prinzip

Der Vollständige Finanzplan (Grob 1989/2006) stellt **alle Zahlungen** einer Investitionsentscheidung je Periode
tabellarisch dar. Dazu gehören die **originären** Zahlungen der Investition (Bau, Mieten bzw. Energieersparnis, Bewirtschaftung,
Restwert) und die **derivativen** Zahlungen aus Finanzierung, Wiederanlage, Steuern sowie Einlagen und Entnahmen der Eigentümer.
Jede Periode wird durch Ausgleichsregeln **auf null ausgeglichen**. Am Horizont ergibt sich der **Endwert** als Guthaben minus
Schulden. Leitprinzipien sind Vollständigkeit (auch Zinseszins auf Zwischenguthaben, Bereitstellungsprovision, Zuschüsse),
explizite Prämissen (Zinssätze, Regeln, Restwertmethode stehen im Bericht) und Transparenz (die Tabelle selbst ist das Ergebnis).

### 2.2 Aufbau der Tabelle: Beispiel

Das folgende Lehrbuchbeispiel ist zugleich Testorakel (a) aus Memo 01. Eine Investition von 100.000 wird finanziert mit
30.000 Eigenkapital, einem Annuitätendarlehen über 40.000 zu 6 % (5 Jahre) und einem endfälligen Darlehen über 30.000 zu 5 %. Der Kontokorrentzins beträgt
10 %, der Habenzins 3 %. Der Rückfluss in t = 5 enthält 40.000 Restwert. Beide Darlehen sind hier zusammengefasst, Werte in €.

| Zeile | t = 0 | 1 | 2 | 3 | 4 | 5 |
|---|---:|---:|---:|---:|---:|---:|
| Zahlungsfolge der Investition | −100.000,00 | 6.000,00 | 10.000,00 | 30.000,00 | 8.000,00 | 70.000,00 |
| Eigenkapital: Einlage | 30.000,00 | – | – | – | – | – |
| Darlehen: Aufnahme | 70.000,00 | – | – | – | – | – |
| Darlehen: Tilgung | – | −7.095,86 | −7.521,61 | −7.972,90 | −8.451,28 | −38.958,35 |
| Darlehen: Sollzinsen | – | −3.900,00 | −3.474,25 | −3.022,95 | −2.544,58 | −2.037,50 |
| Kontokorrent: Aufnahme / Tilgung | – | 4.995,86 | 1.495,44 | −6.491,30 | – | – |
| Kontokorrent: Sollzinsen | – | – | −499,59 | −649,13 | – | – |
| Geldanlage: Anlage / Auflösung | – | – | – | −11.863,72 | 2.639,94 | −29.280,86 |
| Geldanlage: Habenzinsen | – | – | – | – | 355,91 | 276,71 |
| Ertragsteuern (v1: nicht berücksichtigt) | – | – | – | – | – | – |
| **Finanzierungssaldo** | 0 | 0 | 0 | 0 | 0 | 0 |
| Bestand Darlehen | 70.000,00 | 62.904,14 | 55.382,54 | 47.409,63 | 38.958,35 | – |
| Bestand Kontokorrent | – | 4.995,86 | 6.491,30 | – | – | – |
| Bestand Guthaben | – | – | – | 11.863,72 | 9.223,77 | 38.504,63 |
| **Bestandssaldo (Vermögen)** | −70.000,00 | −67.900,00 | −61.873,83 | −35.545,92 | −29.734,58 | **38.504,63** |

Ergebnis: Endwert 38.504,63. Die Unterlassungsalternative (30.000 zu 3 % angelegt) erreicht 34.778,22, die
**Endwertdifferenz beträgt +3.726,41**. Die VoFi-EK-Rendite liegt bei 5,12 %. Mit Restwert amortisiert sich die Investition in t = 5, ohne Restwert
nicht im Horizont (im Lehrbuchbeispiel fällt der Restwert nur in t = 5 an; das Werkzeug weist zusätzlich die Vermögensamortisation mit Restwertpfad aus, 2.5). Der interne Zinsfuß der Zahlungsfolge (5,56 %) liegt über der eigenfinanzierten VoFi-Rendite (5,02 %),
weil er Wiederanlage zu 5,56 % unterstellt, der VoFi aber die tatsächliche Anlage zu 3 %. In der Anzeige können Rundungsdifferenzen von 0,01 auftreten.
Im Werkzeug sind die Zahlungsfolge und die Kredite in Einzelzeilen aufgegliedert, und bei mehr als 15 Perioden wird die Tabelle transponiert gezeigt.

### 2.3 Ausgleichsregeln (Entscheidung D4)

Nach allen exogenen Zahlungen und den Zinsen auf die Vorperiodenbestände verbleibt je Periode ein vorläufiger Saldo. Er wird in fester,
konfigurierbarer Rangfolge ausgeglichen:

| Fall | Rang | Schritt | Begründung |
|---|---|---|---|
| Überschuss | Ü1 | Kontokorrent zurückführen | teuerste Mittel zuerst (Sollzins > Habenzins) |
| | Ü2 | Mindestliquidität auffüllen | Reserve (nur wenn eine Mindestliquidität gesetzt ist) |
| | Ü3 | Sondertilgung (optional, **Standard aus**) | ist nur eine Heuristik und kann den Endwert auch senken |
| | Ü4 | Geldanlage zum Habenzins | Wiederanlage |
| Defizit | D1 | Guthaben oberhalb der Mindestliquidität auflösen | billigste Quelle |
| | D2 | Kontokorrent bis zum Limit | Kosten Sollzins |
| | D3 | Liquiditätsreserve angreifen | wird markiert („Reserve unterschritten“) |
| | D4 | Engpass-Regel: **Unternehmen `penalty_rate`** (zweite Tranche zum Überziehungszins), **Privatpersonen `equity_call`** (Nachschuss aus Haushaltsmitteln), alternativ `stop` | Limitverletzungen werden nie still behandelt, sondern mit Betrag und Periode ausgewiesen |

Beim Wohnungsunternehmen entspricht das Kontokorrent der Betriebsmittellinie bzw. dem Cash-Pool zum internen Verrechnungszins. Bei
Privatpersonen entspricht es Dispositionskredit oder Zwischenfinanzierung. Für Privatpersonen wird markiert, wenn der Nachschuss die angegebene Sparfähigkeit übersteigt.

### 2.4 Zinskonvention und Nicht-Zirkularität (Entscheidung D3)

Die Zinsen der Periode t werden **nachschüssig auf die Bestände am Ende von t−1** berechnet. Der vorläufige Saldo ist damit vor dem
Ausgleich vollständig bekannt. Der Ausgleich verändert nur die Bestände am Periodenende, und diese wirken erst in t+1. Es entstehen keine
Gleichungssysteme und keine Iterationen. Auch ein späterer Steuerbetrag (der von Zinsen abhängt) bleibt rekursiv berechenbar. Sollzinsen
werden gezahlt, nicht kapitalisiert. Habenzinsen fließen in den Saldo und werden über den Ausgleich wieder angelegt (Zinseszins).

### 2.5 Kennzahlen (Entscheidung D9)

| Kennzahl | Bedeutung | Hinweise |
|---|---|---|
| **Endwertdifferenz (primär)** | Endwert der Variante minus Endwert der Referenz (Ohnehin-Variante, Nichtstun oder Unterlassungsalternative) bei gleichem EK-Budget, gleichen Entnahmen und gleichen Kontokonditionen. **Vergleichsregel:** Verglichen wird stets ΔEW_A − ΔEW_B, also jede Variante gegen ihre eigene Unterlassungsalternative mit ihren eigenen endogenen Nachschüssen (bei Unterlassungsalternativen ohne Kontokorrent gleichwertig: EW_A − EW_B abzüglich der mit dem Habenzins aufgezinsten Nachschussdifferenz). Ohne Nachschüsse ist das EW_A − EW_B | immer definiert, additiv, robust auch bei EK = 0 oder Verlusten. Unterschiedliche Nachschüsse sind kein Vergleichbarkeitsfehler, sie werden ausgewiesen. Die Regel ist Teil des Vergleichsvertrags der Spezifikation und wird mit einem eigenen Orakel geprüft (8.3) |
| Endwert | Guthaben − Kontokorrent − Restschulden am Horizont (inkl. Restwert) | mit und ohne Restwert. Restschulden werden nominal abgezogen, eine Vorfälligkeitsentschädigung wird nicht angesetzt (kein erzwungener Verkauf, der Restwert bleibt hypothetisch) |
| VoFi-EK-Rentabilität | Zinssatz, zu dem das eingesetzte EK auf den Endwert anwächst. Bei mehreren Einlagen oder Entnahmen gilt die MIRR-Logik (Aufzinsen bzw. Abzinsen mit dem Habenzins) | **NA mit Begründungscode**, wenn kein EK eingesetzt wurde oder der Endwert ≤ 0 ist. Bei Bestandsobjekten nur definiert, wenn der Bestandswert als Sacheinlage angegeben ist (2.6), sonst NA. Sie hat dieselbe Rangfolge wie die Endwertdifferenz. Der Equity-IRR wird nur ergänzend ausgewiesen |
| Rendite der Mehrinvestition | Habenzins h*, bei dem die Endwertdifferenz gegenüber der Referenz null wird: die VoFi-konsistente Verzinsung des zusätzlich gebundenen Kapitals (Memo 07 S3). ΔEW ≥ 0 bei h = Zielrendite bedeutet h* ≥ Zielrendite | Nullstellensuche mit Monotonieprüfung; NA mit Begründungscode, wenn keine eindeutige Nullstelle existiert. Maßgebliche Renditekennzahl bei Bestandsobjekten |
| Entnahme-Äquivalent | konstanter Betrag, der jährlich zusätzlich entnommen werden kann, ohne schlechter als die Referenz zu stehen | „VoFi-Annuität“, eindeutig über Nullstellensuche |
| Dynamische Amortisation | erstes Jahr, ab dem das Vermögen *dauerhaft* über dem der Referenz liegt, in zwei Begriffen: **„ohne Restwert“** (nur Guthaben und Schulden) und **Vermögensamortisation** mit einem Restwertpfad RW_t je Periode (Komponenten-Zeitwert bzw. Marktwertpfad nach der gewählten Restwertmethode, Memo 01 §4.5) | „keine Amortisation im Horizont“ wird ausdrücklich ausgewiesen. Der Haushaltsmodus zeigt die Vermögensamortisation mit Zeitwert der Maßnahmen, gekennzeichnet |
| DSCR, ICR | Kapitaldienstdeckung (NOI / planmäßiger Kapitaldienst) und Zinsdeckung je Betriebsjahr (Minimum, Jahre unter Schwelle), ausgewiesen **ab dem Stabilisierungsjahr** (Parameter, Standard: erstes volles Betriebsjahr nach Fertigstellung). Zinsen und Raten der Bauphase gehören zur Finanzierung der Investition (KG 800) und zählen nicht mit. Ausweis auf **Objektebene** (inkl. Bestandsdarlehen) und auf **Maßnahmenebene** (nur neue Kredite) | Unternehmenssicht; Covenant-Schwelle als Parameter; Jahre mit Mietminderung werden markiert |
| LTV, Beleihungsauslauf | LTV = Schulden / Marktwert V_t; Beleihungsauslauf = Darlehen / Beleihungswert, mit Beleihungswert = V_t × (1 − Sicherheitsabschlag); V_t ist der Restwertpfad der gewählten Methode | getrennt ausgewiesen; Sicherheitsabschlag als Parameter (Vorschlag 10 %, Abl.); Referenzlinie 60 % des Beleihungswerts |
| Mindestliquidität | minimale Nettoliquidität, maximaler Kontokorrent, Summe der Nachschüsse, Limitverletzungen | Finanzierbarkeit |
| Kritische Werte (Zielwertsuche) | Wert eines Parameters x, bei dem eine Kennzahl ihren Zielwert erreicht: Endwertdifferenz = 0 (Break-even), EK-Rendite = Zielrendite (Zielrenditemiete), DSCR_min = Schwelle bzw. minimale Liquidität = 0 (Liquiditäts-Break-even), Kostendeckung bei Mindest-DSCR (kostendeckendes Nutzungsentgelt), ΔWarmmiete = 0 (warmmietenneutrale Umlage). Parameter: Miete, Investition, Energie- bzw. CO₂-Preis, Anschlusszins, Leerstand, Förderquote, Habenzins, Restnutzungsdauer, Liegenschaftszins, Restwertfaktor | Break-even-Miete, notwendige Förderung, kritische Restnutzungsdauer; Monotonie wird geprüft |
| Warmmietenänderung | Δ(Nettokaltmiete + Umlage + Heiz- und Warmwasserkosten der Mieter + sonstige Betriebskosten) in €/m² und Monat, zweifach: **„vorher/nachher“** gegenüber dem Zustand vor der Maßnahme (für Mieter, Kommunikation und Beschlüsse) und **„Variante gegenüber Referenz“** im selben Jahr (für die Entscheidung). Die Heizkosten der Mieter enthalten nur den Mieteranteil, also ohne die Vermieteranteile an CO₂-Kosten und § 5a-Netzentgelten | Mietersicht, abgeleitet; Pfad je Jahr, Fächer und P(ΔWarmmiete > Schwelle) |
| Haushaltssicht | je Perspektive (Definitionen nach Memo 07 §5.4). **Selbstnutzer:** monatliche Belastung je Kalenderjahr (Zinsen, Tilgung, Energie, Wartung, sonstige variantenabhängige laufende Kosten, abzüglich Einspeiseerlöse; Investitionen aus Eigenmitteln und Zuschüsse sind nicht enthalten, sondern erscheinen als Einmalbeträge), Ersparnis bzw. Mehrkosten pro Monat als Zeitreihe (Kopfwert: erstes volles Nutzungsjahr und Durchschnitt der ersten 10 Jahre), Eigenanteil heute nach Förderung, Summe der Nachschüsse, Belastungsquote, Gesamtkosten über N Jahre. **Kleinvermieter:** monatlicher Cashflow nach Kapitaldienst einschließlich Mieten und Umlage („Zuschuss bzw. Überschuss pro Monat“), zulässige Mieterhöhung je WE | Tilgung zusätzlich „ohne Tilgung“ (Kostensicht) |
| Ergänzend | Kapitalwert und IZF der Zahlungsfolge („finanzierungsneutral, vereinfachte Annahmen“), Förder- bzw. Subventionsbarwert, CO₂-Minderung und -Vermeidungskosten | Anschlussfähigkeit an die Praxis |

### 2.6 Referenzalternativen und Variantenvergleich

- **Unterlassungsalternative:** gleiche Einlagen (inklusive endogener Nachschüsse) und Entnahmen, keine Investition und keine Kredite, die
  Mittel werden zum Habenzins angelegt. Der **Habenzins ist ein zentraler Sensitivitätsparameter**. Bei Privatpersonen ist er z. B. Fest- bzw. Tagesgeld,
  bei Wohnungsunternehmen mit Bestandsverschuldung eher der vermiedene Fremdkapitalzins. Deshalb ist die Voreinstellung für Wohnungsunternehmen der
  Kalkulationszins des Unternehmens (Zielrendite, A2). Dann gilt wegen der Rangidentität (Memo 01 §4.3, Unterlassung ohne Kontokorrent): ΔEW ≥ 0
  gegenüber der Unterlassung genau dann, wenn die EK-Rendite die Zielrendite erreicht. Der Bericht weist die Lücke zwischen EK-Rendite und Zielrendite ausdrücklich aus.
- **Bestandsobjekte** (Sanierung, stufenweise Sanierung, Heizungstausch): Jede Variante enthält die Mieten und den Restwert des ganzen Gebäudes. Die
  Endwertdifferenz zwischen zwei Gebäudevarianten (A2 gegen A1 oder A0) bleibt davon unberührt, weil der Bestand in beiden steckt. Die reine
  Unterlassungsalternative (nur Eigenkapital zum Habenzins, ohne Gebäude) ist hier **als Referenz unzulässig**. Die Validierung verlangt A0 oder A1 und
  meldet sonst einen Fehler, sofern die Abweichung nicht ausdrücklich zugelassen wird. Für eine absolute VoFi-EK-Rendite je Variante ist der **Wert des
  Bestands zum Bewertungsstichtag** anzugeben (Verkehrswert vor der Maßnahme, Opportunität „heute verkaufen“). Er wird abzüglich der Restschuld der
  Bestandsdarlehen als zahlungsunwirksame Sacheinlage in t = 0 aller Varianten gebucht. In der Unterlassungsalternative wird er nach Verkaufskosten und
  Ablösung der Bestandsdarlehen zum Habenzins angelegt. Ohne diese Angabe ist die absolute EK-Rendite NA, und maßgeblich ist die Rendite der
  Mehrinvestition (2.5). Beim Erwerb mit Sanierung ist der Kaufpreis ohnehin eine Investitionsauszahlung.
- **Bei Sanierungen** lautet die entscheidungsrelevante Referenz meist **Ohnehin-Sanierung** (fällige Instandsetzung ohne energetische
  Verbesserung, z. B. Putz, Anstrich, Fenster 2-fach, neuer Gaskessel), nicht das Nichtstun. Standardmäßig rechnet das Werkzeug das Alternativenset aus
  Memo 01 §5.3: A0 Nichtstun bzw. Weiterbetrieb (mit erzwungenen Ereignissen wie dem Kesselausfall), A1 Ohnehin-Sanierung, A2 energetische
  Sanierung und A2′ als Zeitpunktvariante (Kopplung an den Ohnehin-Termin).
- **Jede Variante ist ein vollständiger VoFi.** Verglichen wird über die Differenz der Endwerte. Ein zeilenweiser **Differenz-VoFi** dient nur
  der Erklärung. Ein VoFi auf Differenzzahlungen („nur Mehrkosten und Mehrerträge“) ist bloß ein gekennzeichneter
  Vereinfachungsmodus, weil die Ausgleichsregeln nichtlinear sind (VoFi(A) − VoFi(B) ≠ VoFi(A − B)).
- **Vergleichbarkeit wird erzwungen:** Das Werkzeug prüft gleiches Horizontende (festes Kalenderdatum, 2.8), gleiches EK-Budget (nicht benötigtes EK wird angelegt), gleiche Entnahmen, gleiche Kontokonditionen und
  gleiche Restwertmethode. Abweichungen sind ein Fehler, sofern sie nicht ausdrücklich zugelassen werden. **Endogene Nachschüsse** sind davon ausgenommen: Sie dürfen
  sich zwischen Varianten unterscheiden, werden über die Vergleichsregel ΔEW_A − ΔEW_B neutralisiert und je Variante ausgewiesen (2.5).
- **Ohnehin-Kosten** gehen doppelt ein: im Vollkostenvergleich als eigene Variante mit eigenen Fälligkeitszeitpunkten und
  je Maßnahme als Betrag (`ohnehin`-Anteil). Letzteres braucht § 559 BGB (Erhaltungsabzug) und die Kennzahl
  „energiebedingte Mehrkosten“. Das Werkzeug prüft beide Angaben auf **Plausibilität**: Der mietrechtliche Erhaltungsanteil darf die Ohnehin-Kosten
  nicht übersteigen. Gleichheit wird nicht verlangt, weil § 559 Abs. 2 fiktive Erhaltungskosten unter Berücksichtigung der Abnutzung meint (3.3).

### 2.7 Warum VoFi statt Kapitalwert oder internem Zinsfuß

| Kriterium | Kapitalwert / IZF | VoFi |
|---|---|---|
| Kapitalmarkt | ein Zins für Anlage und Kredit bzw. implizite Wiederanlage zum IZF | Sollzins ≠ Habenzins, mehrere Kredite, Limits |
| Finanzierung und Förderkredite | ignoriert oder nur über manuelle Umrechnung | explizit (Annuität, Raten, endfällig, tilgungsfreie Jahre, Tilgungszuschuss, Bereitstellungsprovision) |
| Liquidität | nicht sichtbar | Kontokorrentbedarf, Nachschüsse und Markierungen je Periode |
| Eindeutigkeit | IZF mehrdeutig bei mehreren Vorzeichenwechseln (Ersatzinvestitionen, Restwert) | Endwert und Endwertdifferenz eindeutig |
| Kommunikation | abstrakte Zahl | Tabelle wie ein Finanzplan oder Kontoauszug |

**Beispiel (Orakel (b), Memo 01):** Eine geförderte MFH-Sanierung hat einen Kapitalwert (2 %) von −13.524,20 bei einem IZF von 0,95 %.
Beide Verfahren würden die Maßnahme verwerfen. Der VoFi zeigt dagegen eine Endwertdifferenz von +9.482,79, weil Tilgungszuschuss und Förderkredit
auf der Finanzierungsseite wirken. Bei vollkommenem Kapitalmarkt (alle Zinsen gleich) liefern beide Verfahren dasselbe Ergebnis. Das ist eine Testinvariante.

### 2.8 Periodizität (Entscheidung D2)

Das Zeitraster ist ein **Vektor von Periodenlängen**. Standard ist ein Jahresraster. Ab v1 sind **nicht äquidistante Raster** möglich, etwa eine
Bauphase in Monaten oder Quartalen und danach ein jährlicher Betrieb. So werden Teilvalutierung, Bauzeit- und Bereitstellungszinsen genau abgebildet, ohne die
30- bis 50-jährige Betriebsphase monatlich rechnen zu müssen. **Module dürfen intern feiner rechnen**: Kredite in ihrer
Vertragsfrequenz (z. B. monatliche KfW-Annuität), das Mietrecht monatlich (15-Monats-Wartefrist, Wirksamkeitsfristen,
Kappungsfenster). Die Ergebnisse werden auf das VoFi-Raster aggregiert. Unterjährige Zahlungen werden am Periodenende gebucht. Den Fehler gibt das Werkzeug an
(bei 12 gleichen Monatszahlungen rund 0,458 × Habenzins × Jahresbetrag, bei 2 % Habenzins also etwa 0,9 % des Jahresbetrags). Wer es genauer braucht,
verfeinert das Raster.

**Horizont.** Das Horizontende ist ein **festes Kalenderdatum**: Bewertungsstichtag (t = 0) plus Horizont in Jahren. Es gilt für alle Varianten und alle
Simulationsläufe. Ein Bauzeitverzug oder eine andere Bauzeit verschiebt nur Mietbeginn, Bauzeitzinsen und Zahl der Nutzungsjahre, nicht das Horizontende.
So bleibt jedes Ergebnis eine N × (T+1)-Matrix mit festem T, und die Endwerte sind vergleichbar (Festlegung F16; Details regelt die Spezifikation beim Zeitraster).

### 2.9 Nominal und real

**Der Kern rechnet nominal**, denn Kreditverträge sind nominal, und nur die Nominalrechnung zeigt die Entwertung fester Schulden durch
Inflation. Eingaben erfolgen in Preisen des Basisjahrs mit nominalen Steigerungsraten oder real plus Inflation, die Eingabe verlangt die
ausdrückliche Wahl. Reale Größen (Endwert in heutiger Kaufkraft, reale Rendite nach Fisher) entstehen nur bei der Ausgabe durch
Deflationierung mit dem (in der Simulation je Lauf stochastischen) VPI-Pfad. Gemischte Real- und Nominalrechnung ist eine klassische Fehlerquelle und
wird durch die Eingabelogik verhindert.

---

## 3. Fachliches Modell

### 3.1 Domänenmodell und Perspektiven

Die Eingabe erfolgt **fachlich** auf der Domänenebene. Sogenannte Expander übersetzen sie in typisierte Zahlungskomponenten, die der generische Rechenkern verarbeitet
(Entscheidung D7).

| Baustein | Inhalt (Auswahl) |
|---|---|
| Projekt | Art (Neubau, Sanierung, stufenweise Sanierung, Heizungstausch, Erwerb + Sanierung), Perspektive, Steuerregime (F9), Bewertungs- und Antragsdatum, Horizont, Bundesland, Gemeindestatus (Mietpreisbremse, 15-%-Kappung, Erhaltungs- bzw. Milieuschutzsatzung), Rechtsstand, Referenzvariante |
| Gebäude | Baujahr, WE, Wohnfläche, Gebäudenutzfläche, Bauteilflächen, Energieklasse, Effizienzhausstufe, WPB-Status, Denkmal; bei Bestandsobjekten Wert des Bestands zum Bewertungsstichtag (2.6) |
| Wohnungsgruppen | Anzahl, Fläche, Ausgangsmiete, Mietregime, Mietrechtshistorie (Miete vor 36 Monaten, letzte § 558-Erhöhung, §§ 559/559e-Erhöhungen der letzten 6 Jahre, § 559c-Sperrfrist), Selbstnutzung, Bindung, optional als Mieterliste je WE (nötig für die Kappung je Wohnung) |
| Maßnahmen | DIN-276-Kostengruppe, Kosten (mit Mengenbezug), Zeitpunkt, Ohnehin-Anteil, Erhaltungsanteil (Methode), Nutzungsdauer, Modernisierungsart (§ 555b), Fördereignung, Wirkung (Energie, Instandhaltung, Leerstand, Miete) |
| Energiesystem | Energieträger je Zustand, Verbrauch bzw. Bedarf, Einbaudatum der Heizung, Plan-JAZ (Nachweis nach VDI 4650) und realisierte JAZ, Vorlauftemperatur, PV (mit USt-Attribut) |
| Förderung | Verweis auf Bibliothekseinträge mit lokalen Abweichungen; Ausweichvariante bei Ablehnung (3.9) |
| Finanzierung und Konten | EK-Budget, Einlagen und Entnahmen, Darlehen, Bestandsdarlehen, Habenzins, Kontokorrent, Limits, Mindestliquidität, Engpass-Regel |
| Markt | Basisannahmen: Inflation, Mietsteigerung, Energie- und CO₂-Preise, Baupreisindex, Anschlusszins |

**Welche Zahlungsreihen gelten für welche Perspektive** (Memo 02 §1.11, verkürzt):

| Zahlungsreihe | Wohnungsunternehmen / Genossenschaft | Kleinvermieter | Selbstnutzer |
|---|---|---|---|
| Investition, Förderung | ja | ja | ja (zusätzlich Einkommens- und Klimageschwindigkeitsbonus) |
| Nettokaltmiete bzw. Nutzungsentgelt, Modernisierungsumlage | ja (Genossenschaft oft freiwillig reduziert) | ja | nein (optional kalkulatorische Miete für Kauf-oder-Miete-Vergleiche) |
| Verwaltung, Instandhaltung, Mietausfallwagnis | ja | ja | nur Instandhaltung |
| CO₂-Vermieteranteil, § 5a-Netzentgelte | ja | ja | nein, volle Energiekosten |
| Energiekosten | nur bei Leerstand | nur bei Leerstand | ja, voll (Haupteffekt) |
| Grundsteuer, Gebäudeversicherung | nur bei Leerstand bzw. in der Bauphase | dito | ja |
| Restwert | ja | ja | ja |

### 3.2 Investition (DIN 276) und Bauphase

| KG | Inhalt | Modellhinweis |
|---|---|---|
| 100 | Grundstück inkl. Nebenkosten | Grunderwerbsteuer nach Land (3,5–6,5 %), Notar/Grundbuch ca. 1,5 %, Makler optional. Erbbauzins als laufende Zahlung möglich |
| 200 | Herrichten, Erschließung, Hausanschlüsse | v. a. Neubau; bei Ersatzneubau Rückbau |
| 300 / 400 | Baukonstruktion / technische Anlagen | Kernposten. Bei Sanierung je Bauteil als Maßnahme, Heizung getrennt (wegen § 559e, § 43 GModG und BEG EM) |
| 500 / 600 | Außenanlagen / Ausstattung | ggf. eigene Erlöse (Stellplätze) |
| 700 | Baunebenkosten | typisch 15–25 % von KG 300+400 (Erfahrungswert), Bibliotheks-Default 20 % (F19); Energieeffizienz-Experte ist förderfähig |
| 800 | Finanzierung | **wird nicht eingegeben**, sondern vom Finanzierungsmodul berechnet (Bauzeit- und Bereitstellungszinsen), um Doppelzählung zu vermeiden |

- **Kosten sind brutto** (Entscheidung D6): Wohnraumvermietung ist umsatzsteuerfrei (§ 4 Nr. 12 UStG), ein Vorsteuerabzug ist ausgeschlossen. Netto
  und USt werden getrennt gespeichert. PV-Anlagen auf oder bei Wohngebäuden tragen 0 % USt (§ 12 Abs. 3 Nr. 1 UStG). Bis 30 kWp gelten die
  Voraussetzungen ohne Nachweis als erfüllt (D6). Bei größeren Anlagen, in Mehrfamilienhäusern von Wohnungsunternehmen häufig, steuert ein Attribut je
  Anlage die Begünstigung, mit Hinweis auf den nötigen Nachweis (Reichweite am Gesetzestext prüfen, 10.2).
- **Mittelabfluss** in der Bauphase linear, als S-Kurve oder nach Ratenplan. Die Finanzierungsreihenfolge (EK zuerst, Förderkredit, Bank oder pro rata) ist ein Parameter.
- **Kostenansätze** stammen aus der Parameterbibliothek mit Unsicherheitsband. Neubau-MFH (KG 300+400) hat den Default 3.750 €/m² Wfl. (Median Großstädte
  Q4/2025 im Intervall 3.500–3.750 €/m², ARGE e. V.). Sanierungsmaßnahmen werden bottom-up über IWU-Kostenfunktionen (Preisstand 2023, mit 1,12 auf
  2026 fortgeschrieben) angesetzt, z. B. WDVS 16 cm ≈ 248 €/m² Bauteilfläche, davon ≈ 119 €/m² energiebedingt. In der Simulation wirkt ein
  Kostenüberschreitungsfaktor **auf die Kostenschätzung einschließlich Risikozuschlag** (Unvorhergesehenes, Bibliotheks-Default 10 %, F19); im Basisfall
  ist der Faktor 1. Ist der Risikozuschlag zusätzlich stochastisch gesetzt, warnt die Validierung vor Doppelzählung. Die Fortschreibung erfolgt über den Baupreisindex.

### 3.3 Ohnehin-Anteil: zwei Begriffe

1. **Wirtschaftliche Ohnehin-Kosten** (Investorensicht): Kosten, die ohne die Maßnahme zu ihrem *Fälligkeitszeitpunkt* ohnehin
   anfallen würden. Der Vorzieheffekt ergibt sich im VoFi automatisch, wenn beide Varianten vollständig gerechnet werden.
2. **Mietrechtlicher Erhaltungsanteil** (§ 559 Abs. 2 BGB): Er mindert die umlagefähigen Kosten. Methoden sind linearer Verschleiß
   (Alter/Nutzungsdauer des ersetzten Bauteils), fester Anteil oder Pauschalen (30 % bei § 559c, 15 % bei § 559e). Erfahrungswert für umfassende
   energetische Modernisierungen ist ein Anteil von 20–50 % (unsicher). Er wird deshalb in der Simulation als Verteilung geführt. Standardmethode je
   Maßnahme ist der lineare Verschleiß (fiktive Erhaltungskosten × min(1, Alter/Nutzungsdauer), Memo 02 §1.4). Die Ohnehin-Vollkosten sind nur eine
   Obergrenze (Plausibilitätsprüfung, 2.6), denn sie enthalten auch Verbesserungen wie hydraulischen Abgleich oder Brennwerttechnik.

**Bedingte Anforderungen** (z. B. Mindestdämmung bei Dacherneuerung nach GModG) gehören in die Ohnehin-Variante. Fehlen sie, gibt das Werkzeug
eine Warnung aus.

### 3.4 Ersatzinvestitionen

Kurzlebige Komponenten werden innerhalb des Horizonts zyklisch ersetzt (Zeitpunkt = Einbau + k × Nutzungsdauer, Kosten über
den Baupreisindex fortgeschrieben). Bibliotheks-Defaults nach Memo 03 (BNB/VDI 2067, überwiegend Qualitätsstufe C/D, Abgleich mit den Originaltabellen
steht aus; abweichende Werte in Memo 02 siehe F19): Gas-Brennwertkessel 18 J. (wandhängend; 15–25), Luft/Wasser-Wärmepumpe 18 J. (15–22), PV-Module 25 J.,
Wechselrichter 12 J., Fenster 40 J. (Holz-Alu 50 J.), WDVS 40 J., Heizkörper bzw. Heizungsverteilung 40 J., Flachdachabdichtung 30 J., Steildach 50 J.,
Putz/Anstrich 15 J. (Memo 02). Bei der Restwertmethode **Komponenten-Zeitwert** geht die nicht verbrauchte Nutzungsdauer des letzten Ersatzes
**anteilig in den Restwert** ein. Das verhindert Sprungstellen und benachteiligt kurze Horizonte nicht. Beim **Ertragswert** ist die Funktionsfähigkeit der
Anlagen bereits in Reinertrag und Restnutzungsdauer enthalten. Ein Komponentenzuschlag ist dort nur als ausdrücklich gekennzeichnetes besonderes
objektspezifisches Grundstücksmerkmal zulässig, und die Validierung warnt vor der Kombination (Doppelzählung). Eine **Doppelzählung** von
Instandhaltungspauschale und expliziter Ersatzinvestition prüft die Validierung ebenfalls.

### 3.5 Erlöse und Mietrecht

Die Mietlogik rechnet intern **monatlich** und wird jährlich aggregiert. Die Rechtsregeln sind reine, versionierte Funktionen. Gesetzesänderungen betreffen
dann nur einen Bibliothekseintrag und eine kleine Regelfunktion.

| Regel | Inhalt (geltendes Recht, Stand 25.10.2026) | Status / Schalter |
|---|---|---|
| § 558 BGB Vergleichsmiete | Wartefrist 15 Monate; Kappung 20 % bzw. 15 % (Landesverordnung) in 3 Jahren, bezogen auf die Miete vor 36 Monaten (Mietrechtshistorie ist Eingabe); Umlagen nach §§ 559 ff. zählen nicht mit; Fördermittel mindern spätere Erhöhungen (§ 558 Abs. 5: 8 % des Zuschusses p. a.); Strategie wählbar (maximal, im Intervall, mit freiwilliger Obergrenze) | geltend; Dauer der Kürzung strittig, daher Parameter |
| § 559 BGB Modernisierungsumlage | 8 % p. a. × (Modernisierungskosten − Erhaltungsanteil − Zuschüsse inkl. Tilgungszuschuss) − Jahresbetrag der Zinsermäßigung bei Förderkrediten (§ 559a Abs. 2 mindert den Erhöhungsbetrag unmittelbar, nicht die Kostenbasis); Zurechnung der Drittmittel zum Modernisierungsanteil einheitlich als Parameter (F14); Kappung 3,00 €/m² in 6 Jahren, 2,00 €/m² bei Ausgangsmiete < 7,00 €/m²; Heizungsanteil (§ 555b Nr. 1a) höchstens 0,50 €/m²: zuerst wird der Heizungsanteil auf 0,50 €/m² gekappt, dann gilt die Gesamtkappe; Erhöhungen der letzten 6 Jahre werden angerechnet; Härtefälle als Quote | geltend |
| § 559c BGB vereinfachtes Verfahren | bis 10.000 € je WE, 30 % Pauschalabzug; Zuschüsse werden abgezogen, die Zinsverbilligung nicht (§ 559a Abs. 2 nicht anwendbar); 5 Jahre Sperrfrist für weitere Erhöhungen | Mietrecht II: 20.000 € (anhängig, BT-Drs. 21/6807) |
| § 559e BGB Heizung (Fassung GModG seit 29.07.2026) | nur wenn Drittmittel in Anspruch genommen werden, sonst § 559 (8 %, Heizungsanteil höchstens 0,50 €/m²); 10 % p. a. × (85 % der aufgewendeten Kosten − in Anspruch genommene Drittmittel), d. h. die 15-%-Erhaltungspauschale bezieht sich auf die Kosten vor Drittmittelabzug (Memo 02, F13; Reihenfolge als Parameter); Pauschale *nicht* für neue fossile Heizungen nach § 43 GModG (Auslegung prüfen); Kappung 0,50 €/m² in 6 Jahren | geltend |
| § 559f BGB (neu durch GModG) | Wärmepumpe: volle Umlagebasis nur bei nachgewiesener JAZ ≥ 2,5 (VDI 4650 Bl. 1, Nachweis vor Inbetriebnahme), sonst 50 % der Kosten. Maßgeblich ist die deterministische **Plan-JAZ** des Nachweises, nicht die in der Simulation gezogene realisierte JAZ; diese wirkt nur auf Strombedarf und Warmmiete. Ausnahmen u. a. Baujahr nach 1996 oder Vorlauf ≤ 55 °C | **nur in Memo 07 belegt** (Wortlaut über dejure), vor Implementierung am Gesetzestext prüfen, auch Grenzfall „≥ 2,5“ oder „> 2,5“ und Lesart der Ausnahmen; Reihenfolge Halbierung/Drittmittelabzug ist ein Parameter |
| § 557a Staffelmiete | keine §§ 558–559b-Erhöhungen während der Laufzeit; Mietpreisbremse je Staffel | Mietrecht II: auch § 559e ausgeschlossen (anhängig) |
| § 557b Indexmiete | folgt dem VPI (in der Simulation stochastisch); § 558 ausgeschlossen; § 559 nur für nicht zu vertretende Maßnahmen, Heizungsmaßnahmen (§ 555b Nr. 1a) aber umlagefähig | Mietrecht II: Dämpfung oberhalb 3 % Indexanstieg in Verordnungsgebieten (anhängig) |
| §§ 556d ff. Mietpreisbremse | Neuvertragsmiete höchstens OVM + 10 %; Neubau (erstmals nach dem 01.10.2014 genutzt) und erste Vermietung nach umfassender Modernisierung ausgenommen; Länderverordnungen bis 31.12.2029 | geltend; im Werkzeug für Neuvermietung bei Fluktuation |
| § 536 Abs. 1a BGB | 3 Monate Minderungsausschluss bei energetischer Modernisierung (§ 555b Nr. 1) | Mietrecht II: auch Nr. 1a (anhängig) |

**Wichtige Wechselwirkungen.** Die Umlage bleibt dauerhaft Teil der Miete. Sie „verbraucht“ jedoch den Vergleichsmietenspielraum des modernisierten Zustands,
sodass spätere § 558-Erhöhungen erst möglich sind, wenn die Vergleichsmiete die umlageerhöhte Miete überholt hat. **Bindet die Kappung**, senkt
weitere Förderung die realisierbare Umlage nicht mehr. Sie entlastet dann den Vermieter und nicht die Miete. Beim Heizungstausch bindet die
0,50-€-Kappe fast immer. **Fällt die Förderung aus**, gilt § 559 statt § 559e, und die Abzüge nach § 559a sowie die Kürzung nach § 558 Abs. 5 entfallen;
die Regelfunktionen rechnen deshalb mit der je Lauf tatsächlich gewährten Förderung.

**Umlage in der Simulation.** Die rechtlich zulässige Umlage richtet sich je Lauf nach den realisierten Kosten und der tatsächlich gewährten Förderung,
die zum Zeitpunkt der Erhöhungserklärung bekannt sind. Spätere Energiepreis- oder JAZ-Pfade ändern sie nicht. **Freiwillige Begrenzungen**
(Unternehmensbeschluss „warmmietenneutral“, Genossenschaftsbeschluss) sind Parameter. Eine warmmietenneutrale Umlage wird vorab im Basisfall als
kritischer Wert bestimmt (ΔWarmmiete „vorher/nachher“ = 0, mit der Preisbasis zum Erklärungszeitpunkt) und als feste Umlage in alle Läufe übernommen.

Weitere Erlöse sind Stellplätze, PV-Einspeisung (EEG-Sätze mit Inbetriebnahmedatum) und frei definierbare Zahlungsreihen. Mieterstrom bzw.
gemeinschaftliche Gebäudeversorgung sind in v1 nur als frei definierte Zahlungsreihe mit Warnung möglich; ein modelliertes Modul folgt in v2 (C10).

### 3.6 Bewirtschaftung

Umlagefähige Betriebskosten sind beim Vermieter **durchlaufend**. Sie werden nur kostenwirksam bei Leerstand, als CO₂-Vermieteranteil, als
Netzentgeltanteil nach § 5a und bei nicht umlagefähigen Positionen.

| Position (Referenz 2026) | ImmoWertV Anl. 3 (Default) | II. BV (§§ 26, 28) ab 01.01.2026 |
|---|---|---|
| Verwaltung je WE und Jahr | 367 € | 372,46 € |
| Instandhaltung je m² Wfl. und Jahr | 14,40 € | 11,50 € (< 22 J.) / 14,58 € (≥ 22 J.) / 18,62 € (≥ 32 J.) |
| Mietausfallwagnis | 2 % des Rohertrags | 2 % |

Die ImmoWertV-Werte werden jährlich mit dem VPI fortgeschrieben (Qualität B). Die II.-BV-Werte stammen aus einem Förderbank-Merkblatt, die amtliche Bekanntmachung
ist nicht eingesehen, und die nächste Anpassung erfolgt zum 01.01.2029. Wohnungsunternehmen überschreiben die Werte mit eigenen Ist-Kosten. Die Grundsteuer ist umlagefähig
(Durchlaufposten), wird aber kostenwirksam bei Leerstand, in der Bauphase und beim Selbstnutzer.

### 3.7 Leerstand und Mietausfall

Getrennt modelliert werden: struktureller Leerstand (regional, Default-Presets von 1,5 % im wachsenden Westen bis 9 % in
Schrumpfungsregionen), Mietausfallwagnis bzw. Forderungsausfall (1–2 %), Fluktuation mit Leerstandsmonaten je Mieterwechsel
(8 % p. a., Experteneinschätzung), Anlaufleerstand im Neubau sowie Mietminderung bzw. Leerstand während der Bauarbeiten. Hinzu kommen
**sanierungsbedingte Zahlungen an Mieter** (Aufwendungsersatz nach § 555a Abs. 3 und § 555d Abs. 6 BGB, z. B. Umzugs-, Hotel- oder Umsetzwohnungskosten,
sowie freiwillige Entschädigungen) und eine **Fluktuationsspitze** nach Sonderkündigung (§§ 555e, 561 BGB), jeweils als Parameter. Die Validierung prüft
die Doppelzählung von Leerstand und Mietausfallwagnis.

### 3.8 Energie und CO₂

**Energiepreis.** Der Arbeitspreis je kWh wird aus Nettokomponenten gebildet und einheitlich brutto gerechnet:
**Arbeitspreis brutto = (Commodity + Netzentgelt + CO₂-Preis × Emissionsfaktor + Rest) × (1 + USt)**; „Rest“ umfasst Energiesteuer, Konzessionsabgabe,
Vertrieb und Marge. Der **Grundpreis** wird getrennt in €/a geführt. Die Aufteilungen nach CO2KostAufG und § 5a beziehen sich auf die Bruttowerte der
jeweiligen Komponente. Der CO₂-Preis wird **ausdrücklich getrennt** geführt, damit der Übergang zum EU-ETS 2 transparent ist. Beobachtete Werte 2026
(brutto, Haushalte): Erdgas EFH Ø 11,93 ct/kWh (Neuverträge 01.10.2026: 13,8 ct), Haushaltsstrom 37,0 ct, Wärmepumpentarif etwa 24 ct (Spanne 20–29 ct,
teils Sek.). Die Bibliotheks-Defaults folgen Memo 03 (Erdgas EFH 12,0 ct, MFH 11,2 ct, Haushaltsstrom 37,5 ct, WP-Strom 26,0 ct; F19). 2026 ist ein
Krisenjahr für Energiepreise (Heizöl im September +74,9 % gegenüber dem Vorjahr). Default ist deshalb ein **12-Monats-Mittel**
statt des Spotpreises, und in der Simulation bewegen sich die Preise um ein Normalniveau zurück (Mean-Reversion). Erdgas wird auf **Brennwert (Hs)**
geführt, die Emissionsfaktoren werden konsistent umgerechnet (Hs/Hi ≈ 1,11).

**CO₂-Preis.** 2026 gilt der BEHG-Korridor von 55–65 €/t (erste Versteigerung am 01.07.2026: 65 €/t). Für 2027 wurde erneut ein Korridor von 55–65 €/t im
Bundestag am 15.10.2026 beschlossen. Die Zustimmung des Bundesrats stand zum Stichtag aus, deshalb ist der Korridor noch nicht in Kraft. Memo 03 und Memo 07 nennen einen älteren
Verfahrensstand. Ab 01.01.2028 gilt der EU-ETS 2 mit Preisstabilitätsmechanismus. Die Bibliothek führt drei nominale Korridore (Memo 03):

| €/t (nominal) | 2028 | 2030 | 2035 | 2040 | 2045 | 2050 |
|---|---:|---:|---:|---:|---:|---:|
| niedrig | 45 | 55 | 75 | 100 | 120 | 140 |
| mittel (Default) | 60 | 75 | 130 | 170 | 210 | 250 |
| hoch (= UBA-Projektion 2026) | 95 | 125 | 200 | 275 | 350 | 425 |

**CO₂-Kostenaufteilung Vermieter/Mieter** (CO2KostAufG, Wohngebäude). Das Stufenmodell richtet sich nach kg CO₂ je m² Wohnfläche und Jahr:

| kg CO₂/(m²·a) | < 12 | 12–17 | 17–22 | 22–27 | 27–32 | 32–37 | 37–42 | 42–47 | 47–52 | ≥ 52 |
|---|---|---|---|---|---|---|---|---|---|---|
| Vermieteranteil | 0 % | 10 % | 20 % | 30 % | 40 % | 50 % | 60 % | 70 % | 80 % | 95 % |

Neu durch das GModG (§§ 5a–5d CO2KostAufG, in Kraft seit 29.07.2026, wirksam ab 2028): Bei **neu eingebauten Gas-, Öl- oder
Flüssiggasheizungen nach § 43 GModG** werden **ab 01.01.2028 die CO₂-Kosten und die Gasnetzentgelte hälftig** geteilt, statt nach dem
Stufenmodell. **Ab 01.01.2029** werden zusätzlich die Mehrkosten des verpflichtenden Bio-Anteils hälftig geteilt, soweit dieser höchstens 30 % des Brennstoffs ausmacht. Eine
Härtefallregel für Kleinvermieter (§ 5d) und die Erstreckung auf Neubauten (§ 5b) sind nur über Sekundärquellen belegt (Sek.). Das Einbaudatum der
Heizung ist deshalb ein Pflichtattribut. Weil § 5a beschlossenes Recht ist, ist die Regel standardmäßig aktiv. **Übergangsregel:** Wird die Heizung wegen
irreparablen Ausfalls weniger als 12 Monate vor dem 01.01.2028 eingebaut, gilt § 5a für 12 Monate nicht (Sek., Memo 02 §3.2); das betrifft z. B. A0 mit
Kesselausfall 2027. Stehen öffentlich-rechtliche Beschränkungen (Denkmalschutz, Erhaltungs- bzw. Milieuschutzsatzung) einer wesentlichen energetischen
Verbesserung entgegen, wird der Vermieteranteil nach § 9 CO2KostAufG gekürzt (Parameter).

**Bio-Treppe (§ 43 Abs. 1 GModG)** für nach dem 29.07.2026 eingebaute fossile Heizungen im Bestand: biogener Anteil 10 % ab 2029, 15 % ab 2030,
30 % ab 2035, 60 % ab 2040. Die Annahme „100 % klimaneutraler Brennstoff ab 2045“ ist eine Ableitung aus dem Klimaneutralitätsziel bzw. dem erst
angekündigten § 42a (Abl.). Sie ist deshalb ein **Szenario-Schalter mit der Voreinstellung „aus“** (F5, D10) und eine **Pflichtsensitivität** („mit/ohne
2045-Stufe“) für jede Variante, die innerhalb des Horizonts nach 2045 fossil heizt. Der Bio-Anteil verteuert den Brennstoff (Biomethan-Mehrkosten rund
6 ct/kWh netto, unsicher). Ab 2030 müssen
Neubauten Nullemissionsgebäude sein, fossile Erzeuger im Neubau sind damit faktisch ausgeschlossen.

**Bedarf und Verbrauch.** Wenn Verbrauchsdaten vorliegen, ist der **gemessene Verbrauch die Basis**. Sonst gelten Prebound-
und Rebound-Faktoren (Faktoren auf den berechneten Bedarf vor bzw. nach Sanierung, im Mittel rund 30 % Prebound in Deutschland). Die Stromkosten der
Wärmepumpe ergeben sich aus Wärmebedarf ÷ realisierte JAZ × Strompreis. Die JAZ hängt vom Zustand ab und steigt mit den Sanierungsstufen. Getrennt
davon steuert die Plan-JAZ des VDI-4650-Nachweises die Umlagebasis nach § 559f (3.5).

### 3.9 Förderung

**Generisches Modell statt fest verdrahteter Programme.** Jedes Förderinstrument ist ein Bibliothekseintrag. Typen: Zuschuss,
Förderkredit, Tilgungszuschuss, Zinsverbilligung, Steuerermäßigung, Mietbindung (Mietobergrenze für gebundene Einheiten). Eine Belegungsbindung mit
Wirkung auf die Erlöse (Zielgruppe, Vermietungsrisiko) folgt in v2. Ein Eintrag enthält die Bemessungsgrundlage mit gestaffelten
Höchstbeträgen je WE, Satzbausteine mit **Bedingungen** (Selbstnutzung, Einkommen, Kinder, Austausch einer fossilen Altanlage, WPB, NH,
SerSan, iSFP), Gesamtobergrenzen, Schwellenwerte, **Gültigkeit nach Antragsdatum und Degression**, den Auszahlungszeitpunkt
(Verwendungsnachweis, Verzögerung), Kumulierungsregeln, die mietrechtliche Wirkung (§ 559a, § 558 Abs. 5) und das Bewilligungsrisiko. Bedingungen
wertet ein sicherer Ausdrucksauswerter aus, der nur zugelassene Operatoren kennt.

**Programmstand 25.10.2026** (Konditionen vom 22.10.2026; alle Programme stehen unter Haushaltsvorbehalt; der Antrag ist vor Vorhabenbeginn zu stellen):

| Programm | Kerndaten | Hinweise |
|---|---|---|
| KfW 261 BEG WG Kredit (Sanierung zum Effizienzhaus) | bis 150.000 €/WE; Tilgungszuschuss seit 21.07.2026: EH 40 EE 10 % / NH 15 %, EH 55 5 % / 10 %, EH 70 0 % / 5 %, EH 85 0 % / 5 %, Denkmal 5 % / 10 %; WPB-Bonus +10 Pp. (EH 40/55/70), SerSan +15 Pp. (EH 40/55) bzw. +5 Pp. (EH 70); EE-Klasse ist Pflicht; Zins 30/5/10: 3,65 %; Bereitstellungsprovision 0,15 % je Monat ab Monat 13; keine Sondertilgung; Baubegleitung mit 50 % Tilgungszuschuss | Für EH 70 ist der WPB-Status das Kernkriterium. Die Wirkung des Tilgungszuschusses als Laufzeitverkürzung ist Default (Sek., Stand 2024) |
| KfW 458 Heizungsförderung Privatpersonen (Zuschuss) | Grundförderung 30 %; Klimageschwindigkeitsbonus 16 % (nur Selbstnutzer), ab 01.02.2027 −4 Pp. je Halbjahr, 0 % ab 01.08.2028; Einkommensbonus 40/30/10 % (zvE ≤ 30/40/50 T€, +10 T€ bei Kind < 18); Deckel 70 % (80 % bei niedrigem Einkommen); förderfähig 1. WE 28.000 € (−750 € je Halbjahr ab 01.02.2027), WE 2–6 je 15.000 €, ab 7. WE je 8.000 €; Effizienzbonus entfallen | Teilwerte (Sek.). Für Q1/2027 ist eine Umstellung der WP-Förderung angekündigt (15 % Grundförderung + 15 % Bonus für EU-Wertschöpfung). Memo 03 §12 nennt veraltete Sätze, maßgeblich ist Memo 02 |
| KfW 459 (Unternehmen, Genossenschaften) | 30 % Zuschuss, Höchstkosten nach Zahl der WE | Staffel analog 458 angenommen, Prüfung offen |
| BAFA BEG EM Gebäudehülle | 15 %, iSFP-Bonus +5 Pp. seit 21.07.2026 nur ab 30.000 € förderfähiger Investition (1 WE) und nach Memo 02 nur auf den übersteigenden Betrag; förderfähige Kosten je Kalenderjahr: 1. WE 30.000 € (60.000 € mit iSFP), WE 2–6 je 15.000 € (30.000 €), ab 7. WE je 8.000 € (15.000 €) | (Sek.); die Auslegung des Bonus ist eine offene Frage |
| KfW 358 / 359 Ergänzungskredit | bis 120.000 €/WE, setzt eine BEG-EM-Zusage voraus; 358 (Selbstnutzer, zvE ≤ 90.000 €) 25/3/10: 2,53 %; 359: 4,62 % | |
| KfW 297 / 298 Klimafreundlicher Neubau | Kredit ohne Tilgungszuschuss; 100.000 €/WE (EH 55, EH 40), 150.000 €/WE mit QNG; EH 40 Standard 35/5/10: 2,94 %; **EH-55-Stufe** 35/5/10: 2,19 %, befristet bis 31.12.2026, Budgetvorbehalt | Ab 2027 entspricht das gesetzliche Referenzniveau etwa EH 55 (Abl.) |
| KfW 300 Wohneigentum für Familien | zvE ≤ 90.000 € (1 Kind) + 10.000 € je weiterem Kind; EH 40; 170.000–270.000 € je nach Kinderzahl und QNG; 35/5/10: 1,00 % | Berechtigungsprüfung ist Pflicht |
| § 35c EStG (Selbstnutzer) | 20 % der Aufwendungen, verteilt 7/7/6 % auf 3 Jahre, höchstens 40.000 € je Objekt, Abschluss vor 01.01.2030, **nicht kumulierbar mit BEG/KfW** für dieselbe Maßnahme | in v1 als Förderinstrument (Entscheidung D5). Das Eingabefeld „voraussichtliche tarifliche Einkommensteuer je Jahr“ deckelt die Ermäßigung je Jahr (nicht nutzbare Beträge verfallen) und löst eine Warnung aus. Im Haushaltsmodus ist „BEG gegen § 35c“ ein vorgeschlagenes Variantenpaar |
| Soziale Wohnraumförderung der Länder | zinsgünstige Darlehen, Tilgungsnachlass, Miet- und Belegungsbindung | v1 generisch (Tilgungsnachlass wie Tilgungszuschuss, Mietobergrenze), Belegungsbindung und Ländereinträge v2 |

Die BEG-Richtlinie läuft laut Sekundärquelle bis Ende 2030. Ob spätere Sanierungsstufen noch gefördert werden, ist **unsicher**, und das Werkzeug
bildet diese Unsicherheit über die Bewilligungswahrscheinlichkeit ab. Der **Antragszeitpunkt** ist wegen der Degression ein entscheidungsrelevanter Parameter. Beispiel
Memo 02: Eine Wärmepumpe für 32.000 € bei zvE 45.000 € ergibt bei Antrag bis 31.01.2027 einen Zuschuss von 15.680 €, ab 01.08.2028 noch 10.000 €.

**Zusagerisiko als Entscheidungsknoten.** Der Antrag ist vor Vorhabenbeginn zu stellen, und die Zusage liegt vor der Vergabe vor. Wird eine Förderung
abgelehnt, wird in der Praxis umgeplant und nicht unverändert gebaut. Deshalb steuert die Bernoulli-Ziehung (D8) bei Förderungen, deren Zusage vor dem
Vorhabenbeginn liegt, die Wahl zwischen der Variante „mit Zusage“ und einer anzugebenden **Ausweichvariante** (z. B. Referenz, Ohnehin-Variante oder
Variante ohne dieses Programm, wie V1 → V1b in S2). Beide werden auf allen Läufen mit gemeinsamen Zufallszahlen gerechnet und je Lauf ausgewählt. Der
Bericht zeigt zusätzlich die bedingten Ergebnisse „mit Zusage“ und „ohne Zusage, dann Ausweichvariante“. Fehlt die Ausweichvariante, deckt der Ausgleich
die Lücke, und eine Warnung erscheint. Für spätere Stufen (Antrag nach Projektbeginn, z. B. S4 2033) und die Programmverfügbarkeit nach 2030 bleibt die
einfache Bernoulli-Ziehung mit Ausgleich bzw. Wegfall der Stufe. **Nach der Zusage verbleibende Risiken** werden eigens geführt: Kürzung oder
Rückforderung des Tilgungszuschusses bei verfehltem Effizienzhausnachweis und Verzug beim Verwendungsnachweis (spätere Auszahlung). Im Bericht prüft
ein **Berechtigungs-Check** die gewählten Programme (Einkommen, Kinder, Standard, Fristen); eine Funktion, die alle berechtigten Programme der Bibliothek
vorschlägt, folgt in v1.1.

### 3.10 Finanzierung

| Baustein | v1 | später |
|---|---|---|
| Darlehenstypen | Annuitäten-, Raten- und endfälliges Darlehen, jeweils mit Teilvalutierung, tilgungsfreien Anlaufjahren, Zinsbindung kürzer als die Laufzeit, Tilgungszuschuss (Wirkung `shorten_term` als Standard oder `reduce_installment`), Tilgungsnachlass, Disagio, Bereitstellungsprovision, Vertragsfrequenz monatlich, vierteljährlich oder jährlich, Kreditbetrag automatisch aus dem Finanzierungsbedarf des Basisfalls (dann als Zusage- bzw. Vertragsbetrag in allen Läufen fest); optional ein Nachfinanzierungsinstrument zum Zinspfad des Laufs plus Aufschlag | Bausparvertrag, Forward-Darlehen, variable Zinsen, Genossenschaftsanteile |
| Bestandsdarlehen | auf dem Objekt lastende Darlehen mit Restschuld, Zins, Ende der Zinsbindung, Rate und Rang; ohne Auszahlung in t = 0, in allen Gebäudevarianten identisch; gehen in DSCR, LTV und Beleihungsauslauf auf Objektebene ein, vorrangige Grundschulden begrenzen den Beleihungsraum | |
| Anschlussfinanzierung | automatisch bei Ende der Zinsbindung: Restschuld zum Anschlusszins (deterministisch, Szenario oder Monte-Carlo-Pfad), Annuität neu auf die Restlaufzeit oder Fortführung mit Zieltilgung | Kündigungsrecht § 489 BGB, Vorfälligkeitsentschädigung |
| Sondertilgung | geplant oder als Regel Ü3 (Standard aus); bei KfW nicht zulässig | |
| Konten | Kontokorrent (Zins, Limit, Strafzins-Tranche), Geldanlage (Habenzins), Mindestliquidität | Ausschüttungsregeln |
| Eigenkapital | EK-Budget (für alle Varianten gleich), Einlagen, Entnahmen, endogene Nachschüsse, bei Bestandsobjekten der Bestandswert als Sacheinlage (2.6) | |

Die Kreditbausteine sind **Zustandsautomaten** (Bestand, Rate, Restlaufzeit, Zinssatz), die die Engine Periode für Periode fortschreibt. Der Tilgungszuschuss ist eine
zahlungsunwirksame Bestandsminderung. **Kreditbeträge sind keine Größe mit Voraussicht:** Zusage- und Vertragsbeträge werden im Basisfall bestimmt und in allen
Läufen festgehalten (abweichend von Memo 05 §5.5, F15). Kostenüberschreitungen eines Laufs deckt der Ausgleich (Kontokorrent, Nachschuss) oder das optionale
Nachfinanzierungsinstrument. Der Tilgungszuschuss bezieht sich auf den festen Zusagebetrag, höchstens auf den tatsächlich abgerufenen Betrag. Zinsniveau Oktober 2026: Effektivzins für Wohnungsbaukredite mit mehr als 10 Jahren Zinsbindung 4,04 % (Bundesbank, August 2026),
Default-Bauzins 10 Jahre 4,1 %, EZB-Einlagesatz 2,50 %.

### 3.11 Restwert

Der Restwert ist eine **eigene Zeile mit wählbarer Methode**. Alle Kennzahlen gibt es **mit und ohne Restwert**. Jede Methode liefert neben dem Wert
am Horizont RW_T einen **Restwertpfad RW_t** je Periode; er dient der Vermögensamortisation sowie LTV und Beleihungsauslauf (2.5).

| Methode | Logik | Voreinstellung für |
|---|---|---|
| Ertragswert (ImmoWertV §§ 27–34, vereinfacht) | Reinertrag des Folgejahres, Liegenschaftszins, Restnutzungsdauer (Anlage 2 mit Modernisierungspunkten, Gesamtnutzungsdauer 80 J.), Bodenwert | Wohnungsunternehmen, Kleinvermieter |
| Komponenten-Zeitwert | Kosten × Restanteil der Nutzungsdauer × Baupreisindex | Einzelmaßnahmen (z. B. Heizungstausch) |
| Sachwert bzw. Marktwertfortschreibung | fortgeschriebener Wert, ggf. mit Effizienzaufschlag | Selbstnutzer-EFH |
| Vervielfältiger | Jahresnettokaltmiete × Faktor (Default 20) | schnelle Szenarien |
| Nutzerwert, null | eigene Angabe bzw. konservativ 0 | Pflichtsensitivität |

Beim Ertragswert enthält der **Reinertrag alle variantenspezifischen, nicht umlagefähigen Kosten des Folgejahres**: CO₂-Vermieteranteil,
§ 5a-Netzentgeltanteil, Bio-Mehrkostenanteil, Leerstand und Instandhaltung. Gleiche Bewirtschaftungskosten für alle Varianten sind nur zulässig, wenn
diese Kosten tatsächlich gleich sind. Optional ist ein Abschlag für anstehenden Heizungsersatz bzw. eine schlechte Effizienzklasse als Parameter mit
Sensitivität vorgesehen; so wird das Stranded-Asset-Risiko fossiler Heizungen sichtbar (Memo 02 §4.1). Komponentenzuschläge zum Ertragswert sind nur nach
3.4 zulässig.

Verkaufskosten am Horizont werden als Parameter abgezogen (Default 3 %). **Die Restwertannahme dominiert lange Horizonte.** In S1 ist die
Restwertdifferenz zwischen den Varianten (≈ 0,93 Mio. € nominal 2056) größer als die Netto-Mehrinvestition und hängt fast nur an der Restnutzungsdauer und am
Liegenschaftszins. Darum gehören zum Pflichtumfang des Berichts der Ausweis ohne Restwert, ein Tornado für diese beiden Größen, ihre kritischen Werte (2.5)
und ihre Variation in der Simulation.

### 3.12 Steuern

**Nicht-Ertragsteuern sind in v1 vollständig enthalten** (Entscheidung D6):

- **Umsatzsteuer** als Kostenbestandteil: Kosten werden brutto angesetzt, und Netto und USt werden getrennt gespeichert. PV auf oder bei Wohngebäuden trägt 0 % USt (bis 30 kWp ohne Nachweis, darüber per Attribut, 3.2). Bei Gewerbeeinheiten oder Mischnutzung
  erscheint eine Warnung („Vorsteuerthematik nicht abgebildet“).
- **Grunderwerbsteuer** je Bundesland aus einer versionierten Tabelle (3,5 % Bayern bis 6,5 % in BB, NW, SL, SH; Sek.). Ein Schalter bezieht beim „einheitlichen
  Vertragsgegenstand“ die Bauleistung ein. Die Freigrenze beträgt 2.500 €. Die Steuer wird mit Aufteilung auf Boden und Gebäude gekennzeichnet, damit ein späteres Steuermodul die AfA-Basis bilden kann.
- **Grundsteuer** als Betriebskosten (siehe 3.6).

**Ertragsteuern: Bewertung und Entscheidung** (Memo 06; 45 Einzelelemente nach Komplexität und Relevanz bewertet):

| Perspektive | Fehler einer Rechnung vor Steuern | Komplexität einer vollständigen Abbildung |
|---|---|---|
| Privater Vermieter | **groß, auch für die Rangfolge** (AfA bzw. Sonder-AfA, Sofortabzug von Erhaltungsaufwand, steuerfreie Veräußerung nach 10 Jahren) | hoch (Einkommensprofil, Einordnung, Fristen) |
| Selbstnutzer | klein: Das Objekt ist steuerneutral. Ausnahmen sind die Wahl BEG oder § 35c und die Abgeltungsteuer auf die Alternativanlage | niedrig |
| Kapitalgesellschaft mit erweiterter Kürzung | mittel (Niveau ≈ 15,8 %, ab 2032 ≈ 10,6 %), die Rangfolge ändert sich selten | mittel; die Prüfung des Kürzungsstatus ist komplex |
| Kapitalgesellschaft ohne erweiterte Kürzung (z. B. privatwirtschaftliches WU, `wu_privat`) | mittel bis groß (Niveau ≈ 30 %, ab 2032 ≈ 26 % mit GewSt-Hinzurechnung) | mittel bis hoch; Pauschalsatz über `tax_flat` möglich, Hinzurechnung erst v2 |
| Vermietungsgenossenschaft (befreit), gemeinnützig | keiner, solange befreit | niedrig (Kennzeichen) |
| Kommunal mit Verlustvorträgen | gering (effektiv ≈ 0 % über Jahre) | hoch (Unternehmensebene) |

**Entscheidung (D5):** v1 rechnet **vor Ertragsteuern**. Der **Steuer-Hook** ist ab v1 verpflichtend. Er läuft in jedem Lauf mit dem Null-Modul `tax_none`,
auch in der Unterlassungsalternative. Jede Zahlungszeile trägt ab v1 Steuer-Kennzeichnungen, Anlagen- und Maßnahmenregister sind vorhanden, und die
Zeile „Ertragsteuern“ ist sichtbar mit dem Vermerk „nicht berücksichtigt“. **Optional und spät in v1** folgt das vereinfachte Pauschalsteuermodul `tax_flat`.
Es arbeitet mit konstantem Grenzsteuersatz, linearer bzw. degressiver AfA und sofortigem Verlustausgleich bzw. Verlustvortrag, ist standardmäßig aus, für Selbstnutzer und steuerbefreite
Rechtsträger gesperrt und als Vereinfachung („keine Steuerberatung“) gekennzeichnet. Memo 06 schätzt den Aufwand auf 5–8 Personentage zuzüglich 3–5 Personentagen
für die Schnittstelle. Die **Pflichttests der Schnittstelle** (Memo 06 §7.12: `tax_none` und Satz 0 ergeben den Vor-Steuer-VoFi, Standardmodell-Test
mit Kalkulationszins i(1 − s), AfA-Summe gleich Bemessungsgrundlage, Invarianz gegen die Chunk-Größe) laufen ab Phase 1 mit einem **Test-Steuermodul mit
Pauschalsatz unter `tests/`**, auch wenn `tax_flat` nicht ausgeliefert wird. So fallen fehlende Felder früh auf. **§ 35c EStG** ist als Förderinstrument
abgebildet (7/7/6 %, höchstens 40.000 €, gegenseitiger Ausschluss mit BEG, Deckelung durch die angegebene tarifliche ESt, 3.9).

Die Option **„Habenzins nach Abgeltungsteuer“** für Privatpersonen (Habenzins × (1 − 26,375 %), mit Kirchensteuer-Option und verfügbarem
Sparer-Pauschbetrag als Parameter) gehört unabhängig von `tax_flat` zum Pflichtumfang von v1 (Kontomodell, WS-D). Sie wirkt in allen Varianten und in
der Unterlassungsalternative. Die Voreinstellung ist „aus“, weil v1 eine Rechnung vor Steuern ist (D5). Für Selbstnutzer und Kleinvermieter ist sie eine
Pflichtsensitivität, und der Bericht nennt die Richtung des Fehlers: Mit Brutto-Habenzins unterschätzt die Rechnung den Vorteil von Sanierung und
Eigentum gegenüber der Geldanlage (Memo 06 §3.2).

Ergebnisse von Kleinvermietern und von Kapitalgesellschaften ohne erweiterte Kürzung (Steuerregime nach F9) tragen einen deutlichen Steuerwarnhinweis;
die Abhilfe ist `tax_flat`, sobald verfügbar. Für steuerbefreite Vermietungsgenossenschaften erscheint ein Warnhinweis, sobald Nebenerlöse des Projekts
(Stromverkauf, PV-Einspeisung, Gewerbe) die Befreiungsgrenzen nach § 5 Abs. 1 Nr. 10 KStG erkennbar belasten (10 %, 30 % bei Mieter- bzw. Gebäudestrom;
Vorschlag: Warnung ab der Hälfte der Grenze). Die Grenze selbst ist eine Unternehmensgröße. Vollständige Einkommen-, Körperschaft- und Gewerbesteuer
folgen ab v2.

---

## 4. Monte-Carlo-Simulation und Sensitivität

### 4.1 Grundidee in Klartext

Ein einzelner Finanzplan rechnet mit *einer* Zukunft. Die Monte-Carlo-Simulation zieht für jede unsichere Größe viele plausible
Werte bzw. Zeitpfade (Zinsen, Energie- und CO₂-Preise, Baukosten, Förderzusage …), rechnet für jede dieser „Zukünfte“ einen
vollständigen VoFi und wertet die Verteilung der Ergebnisse aus. Die Simulation erzeugt kein Wissen über die Zukunft. Sie macht sichtbar, **wie stark das
Ergebnis von den Annahmen abhängt** und ob eine Variante in den meisten Zukünften besser ist.

### 4.2 Was ist unsicher und wie wird es modelliert?

| Größe | Modell (Klartext) | Default (Memo 04, zu validieren) | Kopplung |
|---|---|---|---|
| Anschlusszins nach Ende der Zinsbindung | schwankt um ein langfristiges Niveau zurück (Vasicek), mit Untergrenze | Start ≈ 4,0 %, Niveau 3,75 %, Rückkehrgeschwindigkeit 0,12, Schwankung 0,7 Pp. p. a., Untergrenze 0,5 % | Habenzins und Kontokorrent als Abstand zum Zinspfad; der Abstand wird so gesetzt, dass der Startwert dem deterministischen Habenzins der Perspektive entspricht (A2) |
| Inflation (VPI) | schwankende Jahresrate mit Gedächtnis (AR(1)), Mittelwert selbst unsicher | Mittel ~ N(2,0 %; 0,3–0,5 Pp.) | treibt Indexmiete, Verwaltungskosten, Baupreise |
| Energiepreise (ohne CO₂) | Trend plus Abweichung, die sich abbaut (Mean-Reversion) | Gas σ 8 %, Strom σ 4 %, Heizöl σ 18 % (historisch 2001–2025: Gas 10,2 %, Strom 4,8 %, Heizöl 20,1 %) | Schocks Gas–Strom ρ ≈ 0,5; Gesamtpreis = Commodity + CO₂ × Emissionsfaktor |
| CO₂-Preis | Szenariokorridor (niedrig/mittel/hoch), konsistent über alle Jahre gezogen, optional mit Rauschen | Korridore aus 3.8 | Vermieteranteil nach Stufenmodell hängt vom tatsächlichen Verbrauch ab |
| Mieten | Bestandsmiete an die Inflation gekoppelt plus Schwankung; Marktmiete stärker schwankend | Bestandsmiete b = 0,6–0,8 × Inflation, σ 0,4–0,6 Pp. | Vertragstyp bestimmt die Logik (Index, Staffel, Kappung) |
| Baukosten | Überschreitungsfaktor als PERT-Verteilung auf die Schätzung einschließlich Risikozuschlag | Neubau (0,95; 1,05; 1,35), Sanierung im Bestand (0,95; 1,10; 1,50) | Rangkorrelation mit Bauzeitverzug ≈ 0,5; Kreditbeträge bleiben fest (3.10), Mehrkosten laufen über Ausgleich bzw. Nachfinanzierung |
| Bauzeitverzug | Monate als PERT-Verteilung | Neubau (0; 2; 12), Sanierung (0; 1; 6) | Mietbeginn, Bauzeit- und Bereitstellungszinsen; das Horizontende bleibt fest (2.8) |
| Förderzusage | Zusage ja/nein (Bernoulli), ggf. Höhe diskret; bei Zusage vor Vorhabenbeginn als Entscheidungsknoten mit Ausweichvariante (3.9) | p(Zusage) 0,8–0,95; Förderverfügbarkeit nach 2030 p = 0,7 | ohne Zusage: Ausweichvariante; bei späteren Stufen deckt der Ausgleich die Lücke; Mietrecht mit der tatsächlich gewährten Förderung (§ 559 statt § 559e) |
| Förderrisiken nach Zusage | Kürzung bzw. Rückforderung des Tilgungszuschusses (Bernoulli mit Anteil), Verzug beim Verwendungsnachweis (Monate) | Parameter ohne Kalibrierung in den Memos, Voreinstellung 0 | Tilgungszuschuss, Auszahlungszeitpunkt, Zwischenfinanzierung |
| Einsparrealisierung (Performance Gap) | Faktoren auf den Bedarf vor und nach der Sanierung (Prebound, Rebound) | vorher PERT(0,5; 0,7; 1,0), nachher PERT(0,9; 1,1; 1,4), ρ ≈ 0,3; mit Verbrauchsdaten entfällt der Vorher-Faktor | |
| JAZ der Wärmepumpe (realisiert) | PERT-Verteilung | Bestand (2,6; 3,2; 4,0), Neubau (3,2; 3,8; 4,6) | Strombedarf und Warmmiete; die § 559f-Schwelle 2,5 prüft dagegen die deterministische Plan-JAZ (3.5) |
| Leerstand | Niveau unsicher, jährliche Schwankung | Niveau PERT(0; 2 %; 8 %) | regional |
| Restwert | Exit-Rendite bzw. Liegenschaftszins an den Zins am Horizont gekoppelt; Restnutzungsdauer unsicher | Liegenschaftszins ± 0,5 Pp., Restnutzungsdauer ± 5 J. | |
| Nutzungsdauern, Instandhaltungsniveau, Kesselausfalljahr | PERT bzw. diskret | z. B. WP (12; 18; 25) J. | |

Grundsätze: **Struktur vor Statistik**. Wo ein ökonomischer oder rechtlicher Zusammenhang bekannt ist (Indexmiete folgt dem VPI, Kappungen,
Stufenmodell), wird er abgebildet und nicht über Korrelationen nachgeahmt. **Nur entscheidungsrelevante Unsicherheit** wird modelliert, denn erfahrungsgemäß tragen 5 bis 10
Größen über 90 % der Streuung. Technisch darf trotzdem jede numerische Eingabe stochastisch sein.

### 4.3 Technische Kernentscheidungen (Entscheidung D8)

| Thema | Festlegung | Warum |
|---|---|---|
| Stichprobe | Latin Hypercube Sampling in 10 Replikaten zu je N/10 Läufen (N durch 10 teilbar, F21) | gleichmäßige Abdeckung; ehrliche Standardfehler aus den Replikaten (der naive Standardfehler war im Prototyp 4-fach zu hoch) |
| Läufe | 1.000 (Vorschau), 10.000 (Standard), 50.000 optional für Tail-Kennzahlen im Bericht | Genauigkeit gegen Rechenzeit; der MC-Fehler wird immer mit ausgewiesen |
| Reproduzierbarkeit | **benannte Zufallsströme**: Seed je Größe aus Master-Seed und Namen | gleiche Ergebnisse bei gleichem Seed; ein neuer Parameter verschiebt keine anderen Ziehungen |
| Abhängigkeiten statischer Größen | Rangkorrelation nach Iman-Conover, je Replikat | Randverteilungen bleiben exakt erhalten |
| Abhängigkeiten von Zeitreihen | Cholesky-Zerlegung der Schockkorrelation je Periode; nicht positiv definite Matrizen werden mit Warnung repariert | konsistente Pfade |
| Prozesse | Mean-Reversion für Zinsen, Energie und Inflation; CO₂ als Szenariokorridor; Prozessparameter dürfen selbst unsicher sein | realistische Pfade ohne Explosionen |
| Zufall getrennt vom Rechnen | ein zentraler Sampler, Bausteine ziehen nie selbst | Ergebnis unabhängig von Chunk-Größe und Parallelisierung |

### 4.4 Gemeinsame Zufallszahlen (CRN), verpflichtend

Alle Varianten, die Unterlassungsalternative und alle Differenzen werden **auf denselben Zukünften** gerechnet. Nur so beantwortet „P(A besser als
B)“ die Frage „In wie vielen möglichen Zukünften ist A besser?“. Der Prototyp zeigt den Effekt deutlich: Mit CRN sank der Standardfehler der mittleren
Differenz von 43.931 € auf 4.943 € (Varianzreduktion Faktor 79), und P(A besser) lag bei 4,9 %. Ohne CRN ergaben sich 45,9 %, was inhaltlich falsch ist. Regeln:
Gleiches Risiko bekommt den gleichen Namen. Verwandte, aber verschiedene Risiken (z. B. die Baukosten zweier Ausführungen) bekommen getrennte Namen mit
Rangkorrelation. Differenzen werden **je Lauf** gebildet, nie aus Quantilen. Pfade sind nach Kalenderjahren indiziert, damit Varianten mit anderem
Projektbeginn konsistent bleiben.

### 4.5 Ergebnisse und ihre Lesart

| Ausgabe | Lesart |
|---|---|
| Mittelwert, Median, Quantile 5/25/75/95 % der Endwertdifferenz, Basisfall daneben | Lage und Breite des Ergebnisses. Basisfall und Median weichen ab, vor allem wegen schiefer Eingangsverteilungen (z. B. Baukosten nach oben schief, im Basisfall ohne Überschreitung und ohne Verzug) und wegen Nichtlinearitäten (Kappungen, Ausgleich). Der Bericht benennt die Hauptursachen |
| bedingte Ergebnisse „mit Zusage“ und „ohne Zusage, dann Ausweichvariante“ | Wirkung des Zusagerisikos getrennt von den übrigen Risiken (3.9) |
| P(Endwertdifferenz < 0), P(Variante besser als Referenz) | „In X von 10 Zukünften …“ |
| 5-%-Quantil, Expected Shortfall 5 %, erwarteter Verlust | ungünstige Zukünfte. Das Werkzeug zeigt bewusst das „5-%-Quantil der Differenz“ statt eines VaR mit verwirrendem Vorzeichen |
| P(Liquiditätsengpass), Verteilung des maximalen Nachschusses bzw. Kontokorrents | Finanzierungsrisiko; das P95 des Nachschusses entspricht dem Bedarf an Liquiditätsreserve |
| P(DSCR < Schwelle) ab Stabilisierungsjahr, P(Belastungsquote > 40 %), P(Nachschuss > Sparfähigkeit) | Covenant- bzw. Tragfähigkeitsrisiko; Grundlage der Restriktionsstufe der Ampel (1.4) |
| P(ΔWarmmiete > Schwelle), Fächer der Warmmiete | Sozialverträglichkeit für Mieter bzw. Mitglieder |
| Anteil undefinierter Renditen | NA-Fälle der EK-Rendite (kein EK, Endwert ≤ 0) werden getrennt ausgewiesen |
| Fächerdiagramm je Jahr | Unsicherheit im Zeitverlauf (z. B. Kontostand, Rate nach 2037) |
| MC-Fehler | z. B. „P(Verlust) = 1,8 % ± 0,3 Pp. (MC-Fehler)“, getrennt von der inhaltlichen Streuung |

### 4.6 Sensitivität

- **Tornado und Spider-Plot** (deterministisch, ein Parameter nach dem anderen, Default P10/P90 der hinterlegten Verteilung) entstehen in **einem**
  vektorisierten Lauf. Bei Zeitreihen werden Treiberparameter variiert (Niveau, Trend, Szenario), keine Pfade aus lauter P90-Werten.
- **Kritische Werte bzw. Zielwertsuche** über Nullstellensuche nach 2.5 (z. B. Miete, bei der die Endwertdifferenz null wird oder die EK-Rendite die
  Zielrendite erreicht; Restnutzungsdauer bzw. Liegenschaftszins, bei denen das Vorzeichen kippt). Die Monotonie wird geprüft.
- **Globale Sensitivität aus der Simulation**: Spearman, SRC/SRRC mit R², PRCC und ein Haupteffekt-Index über Klassenbildung. Hinweise für die Lesart: Bei
  gekoppelten Größen können Vorzeichen wechseln (die Inflation wirkt über die Miete positiv, bei gegebener Miete negativ). Für die Rangfolge der
  Varianzbeiträge eignen sich S1 oder SRC² besser als PRCC. Die Rangfolge ist projektspezifisch, und Defaults dürfen keine Wichtigkeit suggerieren.
  Sobol-Indizes folgen in v2.

### 4.7 Stolperfallen

| Falle | Gegenmaßnahme |
|---|---|
| **Scheingenauigkeit**: Verteilungen sind überwiegend Expertenschätzungen, Wahrscheinlichkeiten wirken objektiv | Basisfall und Simulation nebeneinander; Quellen und Qualitätsstufe der Defaults anzeigen; MC-Fehler ausweisen; Rundung im Haushaltsmodus |
| Deterministischer Wert wird als Erwartungswert gelesen | ausdrücklicher Hinweis im Bericht |
| Quantildifferenzen statt Differenzquantilen; P(A > B) ohne CRN | CRN erzwungen; die Oberfläche zeigt nur Quantile der Differenz |
| Sprungstellen (ganzzahlige Nutzungsdauern, Förderzusage, Stufenmodell, Kappungen) | anteiliger Restwert; diskrete Größen gruppiert auswerten; Warnung bei nicht monotonen Break-even-Suchen |
| Tail-Kennzahlen bei zu wenigen Läufen (CVaR schwankte im Prototyp bei 10.000 Läufen stark) | 50.000 Läufe für Berichte mit Tail-Kennzahlen |
| Strukturbrüche über 30–50 Jahre (Recht, Förderung, ETS 2) | Szenario-Mischungen und deterministische Szenario-Sets statt scheinbar präziser Prozesse |
| Doppelzählung von Unsicherheit (Kopplung plus Korrelation) | Ausgabe der realisierten Momente und Korrelationen zur Plausibilisierung |

---

## 5. Software-Architektur im Überblick

### 5.1 Datenfluss

```text
  Szenario (YAML)   Excel-Vorlage        Parameterbibliothek (Förderung, Recht, Preise, Kosten, Prozesse)
        │                │                         │  Quelle, Abrufdatum, gültig von/bis, Qualität A–D
        └───────┬────────┘                         │
                ▼                                  ▼
   Einlesen und Normalisieren ─────►  kanonisches Szenario (Basis + Varianten + Stochastik-Overlay, mit Herkunft)
                                                   │  Schichten mischen, Bibliotheksverweise auflösen,
                                                   │  Variante anwenden, Expander: Domäne → Komponenten
                                                   ▼
                                     aufgelöste Variante  ──►  Validierung (Struktur, Typen, Querbezüge, Plausibilität)
                                                   │
                                                   ▼
                                     Modell (Raster, Komponenten, Kredite, Ausgleichsketten, Steuermodul, Kennzahlen)
                                                   │
               ┌───────────────────────────────────┼───────────────────────────────────┐
               ▼                                   ▼                                   ▼
        Sampler (MC):                    Zahlungskomponenten:                 Periodenschleife t = 0 … T:
        benannte Ströme, LHS,            N × (T+1)-Matrizen,                  Kredite (Zustandsautomaten), Zinsen,
        Iman-Conover, Cholesky           Rechtsregeln, Förderung              Steuer-Hook, Ausgleich, Invarianten
               └───────────────────────────────────┼───────────────────────────────────┘
                                                   ▼
                    Ergebnis: Einzelrechnung (N = 1) / Simulation / Vergleich / Sensitivität
                                                   │
                     Konsole · Excel · Grafiken · HTML-Bericht (Fach/Haushalt) · ab v1.1 Shiny-Viewer

  Registry (Querschnitt): Zahlungsbausteine, Kreditinstrumente, Ausgleichsaktionen, Expander, Verteilungen,
  Prozesse, Kennzahlen, Steuermodule, Rechtsregeln – die Engine kennt keine konkreten Typen.
```

### 5.2 Komponenten

| Komponente | Aufgabe |
|---|---|
| Eingabe | YAML und Excel lesen bzw. schreiben (verlustfreier Round-Trip), Beispielszenarien |
| Szenario-Schichten | Mischen der Parameterschichten, Bibliotheksverweise, Varianten mit expliziten Operationen (setzen, ersetzen, hinzufügen, entfernen), Herkunft je Wert |
| Validierung | vier Ebenen (Struktur, Typparameter, Querbezüge, Plausibilität); sammelt alle Befunde und meldet sie auf Deutsch mit Pfad bzw. Excel-Zelle; Tippfehler-Vorschläge |
| Expander und Rechtsregeln | Maßnahmen, Wohnungsgruppen, Förderung, Energie und Restwert werden zu Zahlungskomponenten. Mietrecht, CO2KostAufG und Förderregeln sind versionierte, vektorisierte Funktionen |
| Sampler | Verteilungen, Prozesse, LHS, Korrelationen, benannte Ströme |
| Engine | Zeitraster, Zahlungskomponenten, Periodenschleife mit Krediten, Zinsen, Steuer-Hook und Ausgleich; Unterlassungsalternative; Laufzeitprüfungen (Finanzierungssaldo = 0, Bestände ≥ 0) |
| Kennzahlen | Registry der Kennzahlen mit NA-Begründungen, mit und ohne Restwert |
| Analyse | Simulation, Variantenvergleich (CRN), Sensitivität, Break-even, Entnahme-Äquivalent |
| Ausgabe | Ergebnisklassen mit `print`, `summary`, `plot` und `as.data.frame`; VoFi-Tabelle im Grob-Layout und transponiert; Excel-Export; HTML-Bericht; Mietersicht (Warmmiete) |

### 5.3 Eingabeformate

- **YAML** ist das kanonische Format: versionierbar, diff-fähig, für Fachentwickler und Archiv. Die **Excel-Vorlage** richtet sich an die Praxis. Sie wird aus
  der Registry generiert, damit Vorlage und Code nicht auseinanderlaufen, und enthält Blätter für Projekt, Markt, Gebäude, Wohnungsgruppen, Maßnahmen, Förderung,
  Finanzierung, Zeitreihen, Unsicherheiten, Korrelationen und Varianten. Eingabefelder sind gelb, Auswahllisten deutsch, und Fehlermeldungen nennen Blatt und Zelle.
  Für Haushalte gibt es eine **reduzierte Haushaltsvorlage** (Projekt, Gebäude, Verbrauch, Heizung, Angebot, Haushalt mit Einkommen und Kindern; alles
  Übrige aus Defaults), ebenfalls aus der Registry generiert. In v1 bedienen typischerweise Mittler das Werkzeug für Haushalte (6.5, A8).
- **Wertangaben** sind möglich als Konstante, Zeitreihe, Wachstum, Bezug auf einen anderen Wert, Mengenbezug (gesamt, je WE, je m² Wohnfläche, je m² Bauteil, je kW/kWp/kWh),
  eingeschränkter Ausdruck oder „automatisch“ (z. B. Kreditbetrag). Unsicherheiten stehen in einem **Stochastik-Overlay**, das auf deterministische
  Eingaben zielt. Der Basisfall bleibt dadurch unverändert.
- **Schichtenmodell** (spätere Schicht gewinnt): Typ-Defaults → globale Defaults → Perspektiven-Profil (z. B. Engpass-Regel) →
  Rechtsstand und Bibliothekseinträge → Nutzerbibliotheken (Unternehmensstandards) → Szenario → Stochastik-Overlay (nur Simulation) → Variante →
  Laufzeit-Overrides (Sensitivität, Shiny). Für jeden Wert wird die **Herkunft** gespeichert und erscheint im Annahmenprotokoll.

Skizze einer Eingabe (zur Veranschaulichung; Schlüsselnamen und Schema regelt die Spezifikation):

```yaml
project:   {perspective: selbstnutzer, project_type: sanierung, horizon_years: 25,
            application_date: 2026-12-15, federal_state: NW, reference_variant: v0_gaskessel}
building:  {construction_year: 1975, n_units: 1, living_area_m2: 140}
measures:
  waermepumpe: {year: 2027, cost: 32960, lifetime_years: 18}
funding:
  heizung: {from: funding/kfw_458_heizung_privat}      # Bibliothekseintrag, Stand 21.07.2026
variants:
  v0_gaskessel: {label: "Gaskessel behalten", remove: [measures.waermepumpe, funding.heizung]}
stochastic:
  settings:   {n_sim: 10000, seed: 4711, sampling: lhs, replicates: 10}
  parameters:
    jaz: {target: measures.waermepumpe.jaz, dist: pert, min: 2.6, mode: 3.2, max: 4.0}
```

### 5.4 Parameterbibliotheken und Pflegeprozess

- **Ein Eintrag je Datei** (z. B. `funding/kfw_261_eh55`). Pflichtmetadaten sind Quelle (Dokument, URL), Abrufdatum, gültig von/bis
  (bei Förderung bezogen auf das Antragsdatum), Qualitätsstufe (A amtlich bzw. Primärquelle geprüft, B Verband/Institut geprüft, C Sekundärquelle,
  D eigene Ableitung bzw. Expertenschätzung) und optional Unsicherheit und Verteilung.
- **Bereiche:** Förderung, Recht (Mietrecht mit Schalter `mietrecht_ii`, CO2KostAufG, GModG mit Bio-Treppe), Preise (Energie, CO₂-Korridore,
  KfW-Zinsen mit Datum), Prozessparameter, Kosten (Bewirtschaftung, Kostenkennwerte, Nutzungsdauern), Bewertung (ImmoWertV Anlage 2,
  Liegenschaftszinsen, Grunderwerbsteuer) sowie in Vorbereitung Steuerparameter.
- **Warnungen:** wenn das Antragsdatum außerhalb der Gültigkeit liegt, wenn das Abrufdatum älter als 6 Monate ist bzw. bei Kalibrierungsdefaults älter als 12 Monate
  („Parameter veraltet“), und wenn eine anhängige Reform aktiviert wurde.
- **Pflegeprozess:** Änderungsbedarf (Stichtagskalender in 6.3) → Prüfung am Primärtext → neuer bzw. geänderter Eintrag mit Metadaten
  → automatische Schemaprüfung und Regressionstests der Referenzszenarien → Freigabe im Vier-Augen-Prinzip → Versionskennung der Bibliothek
  (`JJJJ.MM.n`). **Jedes Ergebnis speichert die aufgelöste Spezifikation und den Bibliotheksstand.** Eine Aktualisierung ändert also keine
  früheren Ergebnisse.
- Unternehmen können **eigene Bibliotheken** (Ist-Kosten, Konditionen, Zielrenditen) als Schicht über die mitgelieferten legen.

### 5.5 Ausgaben

| Ausgabe | Inhalt v1 |
|---|---|
| Konsole | Kopfkennzahlen, VoFi-Tabelle im Grob-Layout (ab 15 Perioden transponiert), deutsches Zahlenformat (1.234.567, 3,80 %, 25.10.2026) |
| Excel-Export | Übersicht, VoFi, VoFi transponiert, Kennzahlen (auch je WE und je m²), **Annahmen mit Herkunft**, Prüfungen; bei Simulation zusätzlich MC-Statistik, Kennzahlen je Lauf und Pfad-Quantile; bei Vergleich die Varianten. Der **Finanzierungssaldo steht als Excel-Formel** in der Tabelle, sodass Controller die Nullsumme selbst prüfen können |
| Grafiken | Vermögens- bzw. Kontostandsverlauf, Differenzvermögen mit Amortisationsmarke, gestapelte Zahlungsblöcke, monatliche Belastung, Warmmietenpfad, Restschuld, Verteilung bzw. Verteilungsfunktion der Endwertdifferenz mit P(> 0), Fächerdiagramm, Tornado, Konvergenz, Zeitstrahl der Maßnahmen, CO₂ je Variante (Okabe-Ito-Palette, deutsche Beschriftung) |
| HTML-Bericht | Fach- oder Haushaltsmodus: Ergebnis auf einen Blick (zweistufige Ampel), Variantenvergleich, Zeitverläufe, Finanzierung und Förderung (mit Berechtigungs-Check), Miete und Umlage, Energie und CO₂, Risiko, Annahmenprotokoll, VoFi-Tabellen, **Pflichtsensitivitäten** (Restwert = 0; Variation des Habenzinses, bei Wohnungsunternehmen mit 2,0 % und mit dem vermiedenen FK-Zins, bei Privatpersonen „nach Abgeltungsteuer“; mit/ohne 2045-Stufe bei fossilen Varianten), Methodik und Grenzen, Haftungs- und Steuerhinweis. Dazu die **Kurzvorlage** (1.4) mit druckfähigem Layout (Print-CSS, PDF über den Browser) für Aufsichtsrat, Vertreterversammlung oder Bank. DOCX ist technisch vorbereitet und wird mit v1.1 freigegeben, weil es eine eigene Vorlage und Layouttests braucht; die druckfähige Kurzvorlage deckt den Gremienbedarf in v1 |
| Datenexport | Long-Format (Zeile × Periode × Lauf × Wert) für eigene Auswertungen |

Ein Lauf speichert Version, Seed, Rechtsstand, Bibliotheksstände und die aufgelöste Spezifikation. Bei der Simulation werden standardmäßig die Kennzahlen aller Läufe,
die Fächerbänder und vollständige Tabellen für ausgewählte Läufe (P5, P50, P95) gespeichert. Diese werden gezielt neu gerechnet, damit der Speicherbedarf beherrschbar bleibt.

### 5.6 Erweiterbarkeit (Registry)

Die Engine kennt nur Arten von Bausteinen, keine konkreten Typen:

| Art | Beispiele v1 | später |
|---|---|---|
| Zahlungsbaustein | Investition, Grundstück, Mietpfad, Modernisierungsumlage, Betriebskosten, Instandhaltung, Ersatzinvestition, Energiekosten, CO₂-Kosten, Zuschuss, kalkulatorische Miete, Restwert, frei definierte Reihe, Einlagen und Entnahmen | PV-System detailliert, Belegungsbindung, Teilverkauf |
| Kreditinstrument | Annuitäten-, Raten- und endfälliges Darlehen (auch als Bestandsdarlehen ohne Auszahlung), optionale Nachfinanzierung | Bauspar, Forward, variabel, Genossenschaftsanteile |
| Ausgleichsaktion | Kontokorrent tilgen bzw. aufnehmen, Reserve, Anlage bzw. Auflösung, Nachschuss, Strafzins, Stopp | Sondertilgungsregel (Code vorhanden, Standard aus), Ausschüttungsregel |
| Verteilung, Prozess | fixed, normal, trunkiert, lognormal, uniform, Dreieck, PERT, Beta, Bernoulli, diskret, empirisch; AR(1), gekoppeltes AR(1), Vasicek, Mean-Reversion mit Trend, GBM, Szenario-Mix, iid, fester Pfad | Mischverteilungen, Bootstrap, Regimewechsel |
| Kennzahl, Steuermodul, Rechtsregel, Expander | siehe Kapitel 2 und 3; `tax_none`, optional `tax_flat` | Vollsteuermodule |

**Ein neues Förderprogramm braucht keinen Code**, sondern nur einen Bibliothekseintrag nach dem generischen Schema. Ein neues Kreditprodukt mit
neuer Mechanik ist eine neue Datei mit Typdefinition. Ein automatischer Vertragstest prüft jeden registrierten Typ (Dimensionen, Vorzeichen,
Steuer-Kennzeichnungen, Gleichheit von Einzel- und Batch-Lauf). Fremdpakete können Typen registrieren.

### 5.7 Performance

| Vorgang | Ziel v1 | Prototyp |
|---|---|---|
| Einzelrechnung (bis 83 Perioden) | < 50 ms Kern, < 0,5 s inkl. Einlesen | 2–11 ms |
| Simulation 10.000 × 50–53 Perioden inkl. Kennzahlen | < 1,5 s | 0,12–0,25 s |
| Simulation 10.000 × 80–83 Perioden | < 3 s | 0,30–0,50 s |
| Variantenvergleich 5 × 10.000 (CRN) | < 8 s | ≈ 1,5 s (hochgerechnet) |
| Tornado 20 Parameter × 2 | < 1 s | ≈ 0,1–0,2 s |

Eine skalare Engine, die 10.000-mal aufgerufen wird, brauchte 36–47 s, und R6- bzw. Tidy-Varianten waren 100- bis 180-fach langsamer. In v1 gibt es **keine
Parallelisierung**, sie ist nicht nötig. Später ist sie optional über `future.apply` möglich, ohne dass sich die Ergebnisse ändern.

---

## 6. Was benötigt wird

### 6.1 Softwareumgebung

| Komponente | Bedarf |
|---|---|
| R | ≥ 4.3 (Prototypen gemessen mit R 4.3.3) |
| Pflichtpakete (Imports) | `yaml`, `openxlsx` (rekursiv 6 Fremdpakete) sowie `stats`, `utils`, `tools` aus Base R |
| Optionale Pakete (Suggests) | `ggplot2` (Grafiken), `rmarkdown` und `knitr` (Bericht, Vignetten), `shiny`, `bslib`, `DT` (ab v1.1), `future` und `future.apply` (optional parallel), `jsonlite` (JSON-Schema-Export), `testthat` (≥ 3), `withr`, `vdiffr` (Tests) |
| Werkzeuge | pandoc für HTML- bzw. DOCX-Berichte; Excel oder LibreOffice für die Vorlage; Git für YAML-Szenarien und Bibliotheken |
| Nur Entwicklung | Python 3 (Referenzskript der Testorakel aus Memo 01), `covr`, `lintr`, CI mit `LANG=C.UTF-8` |
| Datenschutz | Verarbeitung lokal; Einkommen und Kinderzahl sind personenbezogene Daten. Es gibt keine Übermittlung, und der Bericht enthält einen Hinweis |

### 6.2 Daten, die der Nutzer liefern muss

P = Pflicht, E = dringend empfohlen, O = optional, D = Default aus der Bibliothek verfügbar, – = nicht relevant.

| Daten | WU / Genossenschaft | Kleinvermieter | Selbstnutzer Bestand | Selbstnutzer Neubau |
|---|---|---|---|---|
| Projekt: Bundesland, Gemeindestatus (Mietpreisbremse, Kappung 15 %, Erhaltungs- bzw. Milieuschutzsatzung), Antragsdatum, Horizont, Referenzvariante, Steuerregime | P | P | P | P |
| Gebäude: Baujahr, WE, Wohnfläche, Bauteilflächen; Energieklasse bzw. WPB, Denkmal | P | P | P | P (Planwerte) |
| **Bestand: Wert zum Bewertungsstichtag** (Verkehrswert vor der Maßnahme) und **Bestandsdarlehen** (Restschuld, Zins, Zinsbindung, Rate, Rang) | E (Pflicht für absolute EK-Rendite und Objekt-DSCR) | E | O | – |
| **Verbrauch der letzten 3 Jahre je Energieträger** (Abrechnungen); ersatzweise Bedarf mit Prebound-Default | E | E | E | – (Bedarf aus Planung) |
| Heizung: Art, Einbaujahr, funktionsfähig?, Vorlauftemperatur; bei Wärmepumpe Plan-JAZ des VDI-4650-Nachweises | P | P | P | P |
| Mieten: je Wohnung bzw. Gruppe Fläche, Nettokaltmiete, Mietregime (Staffel, Index); **Mietrechtshistorie** (Miete vor 36 Monaten, Datum der letzten § 558-Erhöhung, §§ 559/559e-Erhöhungen der letzten 6 Jahre, laufende § 559c-Sperrfrist); ortsübliche Vergleichsmiete vor und nach Modernisierung; Leerstand | P | P | – | – |
| Bewirtschaftung: Ist-Kosten Verwaltung und Instandhaltung | O (D) | O (D) | O (D) | O (D) |
| Maßnahmen: Kosten (Angebote bzw. DIN-276-Schätzung), Zeitpunkt, Ohnehin-Anteil, Zahlungsplan | P (Ohnehin E) | P (Ohnehin D) | P (iSFP) | P |
| Förderung: gewünschte Programme, ggf. Zusage, Ausweichvariante bei Ablehnung; Haushalt: zvE (Ø 2. und 3. Vorjahr), Kinder unter 18 | P | P | P | P |
| Finanzierung: EK-Budget, Darlehensangebote (Zins, Zinsbindung, Laufzeit, Tilgung, tilgungsfreie Jahre), Habenzins, Kontokorrent bzw. Limit | P (Konten D) | P | P | P |
| Haushalt: Nettoeinkommen (Belastungsquote), Sparfähigkeit, Miete bis zum Einzug; voraussichtliche tarifliche ESt (für § 35c) | – | O | E | P |
| Restwert: Bodenrichtwert, Liegenschaftszins (Grundstücksmarktbericht), Restnutzungsdauer bzw. Marktwert | E (D) | E (D) | O (D) | O (D) |
| Unternehmensvorgaben: Zielrendite bzw. Kalkulationszins (Voreinstellung des Habenzinses), DSCR-Covenant, Stabilisierungsjahr, Beschlüsse (Umlagebegrenzung, Warmmietenneutralität) | E | – | – | – |
| Unsicherheiten: eigene Bandbreiten statt Defaults | O (D) | O (D) | O (D) | O (D) |

### 6.3 Parameterbibliotheken: Inhalt, Verantwortung, Kalender

Vorschlag: eine **fachlich verantwortliche Stelle beim Auftraggeber** (Bibliothekspflege) und ein technischer Prüfer (Regressionstests). Siehe offene Frage C1.

| Bereich | Bekannte Stichtage und Rhythmus |
|---|---|
| Förderung KfW/BAFA | **01.02. und 01.08.** jedes Jahres (Degression KfW 458/459 ab 01.02.2027: Klimageschwindigkeitsbonus bis 01.08.2028, förderfähige Kosten der 1. WE bis 01.08.2030); angekündigte Umstellung der WP-Förderung Q1/2027; Ende der EH-55-Stufe KfW 297/298 am 31.12.2026; Laufzeit der BEG-Richtlinie bis Ende 2030 (Sek.); sonst bei jeder Programmänderung |
| KfW-Zinsen, Marktzinsen | laufend (Konditionen werden bei Zusage fixiert); Defaults und Prozess-Startwerte vierteljährlich |
| CO₂ | BEHG-Korridor 2027 (Bundesrat), ETS 2 ab 01.01.2028 inkl. MSR-Reformen; Korridore jährlich prüfen |
| Recht | Mietrecht II (bei Verkündung; Schalter bleibt bis dahin aus); GModG Art. 2 voraussichtlich 01.01.2027 (Abl.; neue Primärenergie- und Emissionsfaktoren, die Faktoren nach Anlage 9 gelten nur bis 31.12.2026); CO2KostAufG § 5a ab 2028/2029; Mietpreisbremse bis 31.12.2029; GModG-Evaluation 2030 |
| Bewirtschaftung | ImmoWertV Anlage 3 jährlich (Januar); **II. BV alle 3 Jahre** (nächste Anpassung 01.01.2029) |
| Energiepreise | vierteljährlich (12-Monats-Mittel); EEG-Einspeisevergütung halbjährlich (01.02./01.08.) und Reform 2027 |
| Baukosten, Baupreisindex | halbjährlich |
| Grunderwerbsteuer, Liegenschaftszinsen | jährlich bzw. bei Änderung durch ein Land (Bremen: Rücknahmeantrag zum 01.01.2027 offen); Grundstücksmarktberichte |
| Nutzungsdauern | bei Neufassung der BNB-Tabelle (Überarbeitung angekündigt) |
| Steuerparameter (für `tax_flat` bzw. v2) | jährlich; befristete Normen (§ 35c bis 31.12.2029, degressive AfA und § 7b bis 30.09.2029) |

### 6.4 Qualitätssicherung

- **Fachlich:** Jede Angabe trägt Quelle, Datum und Qualitätsstufe. Werte der Stufe C oder D werden im Annahmenprotokoll hervorgehoben. Rechtsregeln werden vor der
  Freigabe am Gesetzestext geprüft (Liste ungeprüfter Punkte in 10.2); was nicht prüfbar ist, behandelt die Freigaberegel in 6.5.
- **Technisch:** Testorakel, Invarianten in jedem Lauf, eine unabhängige Referenz-Engine, Referenzszenarien mit Prüfwerten und statistische Tests
  (Kapitel 8). Eine Bibliotheksänderung löst die Regressionstests der Referenzszenarien aus, und Abweichungen werden bewusst freigegeben.
- **Ergebnisse:** Laufzeitprüfung „Finanzierungssaldo = 0 in jeder Periode und jedem Lauf“. Ein Prüfblatt im Excel-Export und ein Prüfabschnitt im Bericht
  geben die maximale Abweichung je Invariante aus.

### 6.5 Rollen, Freigaberegel und Aufwand

| Rolle | Aufgabe | Wer |
|---|---|---|
| Entscheidung | Antworten auf die offenen Fragen (11.3), Abnahme der Phasen | Auftraggeber |
| Bibliothekspflege | Einträge und Stichtagskalender (6.3, C1) | Fachstelle beim Auftraggeber |
| **Fachlich-juristische Prüfung** | Rechtsregeln und Förderauslegungen am Primärtext (Liste 10.2, Auslegungen B1 und B2), fachliche Freigabe der Bibliothek | Auftraggeber (Rechts- bzw. Förderfachkunde) oder extern beauftragt (B14) |
| Technischer Prüfer | Regressionstests, bewusste Freigabe geänderter Prüfwerte | Integrator |
| Bedienung für Haushalte | Eingabe, Rechnung und Übergabe des Berichts an den Haushalt | Mittler wie Energie- oder Förderberatung, Wohnungsunternehmen, Verbraucherberatung (A8) |

**Freigaberegel für Rechtsregeln und Bibliothekseinträge.** (1) Am Primärtext geprüft: Qualitätsstufe A, Voreinstellung nach F5. (2) Verkündetes Recht,
aber nicht am Primärtext geprüft (z. B. § 559f, §§ 5b und 5d CO2KostAufG): Qualitätsstufe C mit sichtbarem Hinweis im Bericht; standardmäßig aktiv nur
nach ausdrücklicher, protokollierter Freigabe durch die fachlich-juristische Prüfung, sonst aus. (3) Eigene Ableitung (Abl.), z. B. die 2045-Stufe:
Qualitätsstufe D, nie standardmäßig aktiv, sondern Szenario-Schalter. Nicht prüfbare Punkte bleiben in Stufe C bzw. D und erscheinen im Annahmenprotokoll.

**Aufwand (grobe eigene Schätzung, Abl., vor Phase 0 zu bestätigen).** Den Code schreiben KI-Agenten: Phase 0 seriell, Phase 1 mit 9 und Phase 2 mit
7 Arbeitspaketen, Phase 3 als unabhängige Verifikation. Für die Dauer maßgeblich sind die menschlichen Prüf- und Entscheidungsschritte: A-Fragen und
Freigabe der Verträge vor Phase 0 (≈ 2–3 Personentage), B-Fragen und fachliche Durchsicht der Referenzszenarien in Phase 2 (≈ 3–5 PT),
fachlich-juristische Prüfung der Liste 10.2 (≈ 5–10 PT, je nach Verfügbarkeit der Primärtexte), Bibliotheksfreigabe und Abnahme v1 (≈ 3–5 PT).
Hinzu kommt die laufende Pflege nach 6.3.

---

## 7. Umfang und Ausbaustufen

### 7.1 Funktionsumfang je Stufe

| Funktion | v1 | v1.1 | v2 |
|---|---|---|---|
| Einzelprojekt bzw. Einzelgebäude mit beliebig vielen Varianten, Neubau und Sanierung (auch stufenweise) | ● | | |
| Zeitraster jährlich, nicht äquidistant (Bauphase monatlich bzw. quartalsweise), Module mit interner Monatsrechnung | ● | | |
| Ausgleichsketten, Engpass-Regeln, Unterlassungsalternative, Total- und Differenz-VoFi | ● | | |
| Darlehen (Annuität, Raten, endfällig, Tilgungszuschuss, Bereitstellungsprovision, Anschlussfinanzierung), Bestandsdarlehen, optionale Nachfinanzierung | ● | | Bauspar, Forward, variabel, § 489 |
| Mietrecht §§ 558, 559, 559a, 559c, 559e, 559f, Staffel, Index, Mietpreisbremse; Schalter Mietrecht II | ● | | |
| CO2KostAufG (Stufenmodell, § 5a), Bio-Treppe, Energie mit CO₂-Komponente, Prebound/Rebound, PV vereinfacht | ● | | stündliche PV- bzw. WP-Simulation |
| Generisches Fördermodell mit BEG/KfW-Bibliothek, § 35c als Instrument, Zusage als Entscheidungsknoten, Berechtigungs-Check der gewählten Programme | ● | Vorschlag aller berechtigten Programme | Länderprogramme als Einträge, Belegungsbindung |
| Restwertverfahren (Ertragswert, Komponenten, Sachwert, Vervielfältiger, Nutzerwert, null) | ● | | |
| Nicht-Ertragsteuern (USt, GrESt, Grundsteuer); Steuer-Hook mit `tax_none` und Pflichttests mit Test-Steuermodul; Option „Habenzins nach Abgeltungsteuer“ (Voreinstellung aus) | ● | | |
| Pauschalsteuermodul `tax_flat` | ○ (spät, optional) | | |
| Vollständige Ertragsteuer (ESt-Tarif, KSt, GewSt, § 7b-Prüfungen, Mischnutzung) | | | ● |
| Monte Carlo (LHS, Korrelationen, Prozesse, CRN), Sensitivität, Zielwertsuche, Szenario-Sets inkl. „vorsichtig“ (Ampelbasis) | ● | weitere Presets „Basis / optimistisch“ | Sobol, t-Copula |
| Kennzahlen nach D9 (inkl. Rendite der Mehrinvestition, Vermögensamortisation, Kennzahlen je WE und m²), Mietersicht Warmmiete | ● | | vollständige Mieter-VoFi |
| Excel-Eingabe (auch reduzierte Haushaltsvorlage) und Excel-Export, HTML-Bericht in zwei Modi mit druckfähiger Kurzvorlage | ● | DOCX-Freigabe, Blatt „Rechenweg“ mit Live-Formeln, Erklärfunktion je Zeile, Archivfunktion für aufgelöste Szenarien | PDF-Erzeugung im Werkzeug, Corporate-Design-Vorlagen |
| HGB-Sicht | | indikative Aufteilung „Aufwand / aktivierungsfähig“ (nicht HGB-geprüft) | HGB-Vorschau (v2+) |
| Shiny-Viewer (Laden, Regler, Ergebnisse, Vergleich, Downloads) | Stub | ● | Szenario-Editor, Mehrbenutzerbetrieb |
| Portfolio, Kostenmiete II. BV, WEG, gemischte Nutzung | | Batch-Lauf mit Summenzeile (Vorschlag) | ● |

● = enthalten, ○ = optional. Die Gesellschafterebene (Ausschüttungen an Gesellschafter bzw. Mitglieder) bleibt außerhalb des Scopes (C11).

### 7.2 Abdeckung der 25 Adaptivitätsanforderungen (Memo 07)

| ID | Anforderung | Prio Memo 07 | Umsetzung |
|---|---|---|---|
| A-01 | beliebiger Horizont und Startjahr, eigene Preisbasis | M | v1 |
| A-02 | Periodizität: jährlich, Darlehen monatsgenau, Monatswerte für Haushalte | M (unterjährig v2) | **v1 inklusive nicht äquidistanter Bauphase** (Entscheidung D2) |
| A-03 | Maßnahmen zu beliebigen Perioden mit Wirkungen | M | v1 |
| A-04 | mehrere Varianten, Referenzvariante, Vererbung nur mit expliziten Operationen | M | v1 |
| A-05 | Ohnehin-Logik doppelt (Variante und Anteil) mit Konsistenzprüfung | M | v1, als Plausibilitätsprüfung Erhaltungsanteil ≤ Ohnehin-Kosten (2.6) |
| A-06 | Bauphase bzw. Zahlungsplan, Erstvermietung, Mietminderung | M | v1 |
| A-07 | mehrere Darlehen aller Grundtypen inkl. Tilgungszuschuss, Disagio, Bereitstellungsprovision | M (Bauspar, Forward v2) | v1; Bauspar und Forward v2 |
| A-08 | Anschlussfinanzierung automatisch (deterministisch, Szenario, MC-Pfad) | M | v1 |
| A-09 | VoFi-Ausgleichsmechanik, gleiches EK-Budget je Variante | M | v1 |
| A-10 | Zuschüsse mit Auszahlungsverzug | M | v1 |
| A-11 | benutzerdefinierte Zahlungsreihen | M | v1 |
| A-12 | Indizes (VPI, Baupreis, Instandhaltung, Miete, Boden, Energie), deterministisch oder stochastisch | M | v1 |
| A-13 | überschreibbare, versionierte Parameterbibliotheken mit Stichtagslogik | M | v1 |
| A-14 | Mengenbezug (gesamt, je WE, je m², je Bauteilfläche, je kW/kWp/kWh) | M | v1, Ausgabe auch je WE und je m² |
| A-15 | vereinfachte Energiebilanz, Prebound/Rebound, JAZ je Zustand, PV vereinfacht | M (stündlich v2) | v1; stündlich v2 |
| A-16 | Restwertverfahren wählbar, Ausweis immer auch ohne Restwert | M | v1 |
| A-17 | Mietrechtsmodul inkl. § 559f, freiwillige Kappung, Härtefälle | M (§ 558 detailliert S) | v1 inkl. Monatslogik § 558 |
| A-18 | CO2KostAufG und § 5a, Einbaudatum als Attribut | M | v1 |
| A-19 | Zielwertsuche (Break-even-Miete, Investition, Förderung, Preise) | S | v1, allgemein für beliebige Kennzahl und Zielwert (2.5) |
| A-20 | Perspektiven: Eigentümer-VoFi und Warmmietensicht | M (Mieter-VoFi v2) | v1; Mieter-VoFi v2 |
| A-21 | Monte Carlo für jeden numerischen Parameter, Korrelationen, CRN, Konvergenz | M (Zeitreihen S) | v1 inkl. Zeitreihenprozesse |
| A-22 | Steuern | v2 (Hook M) | Hook und Kennzeichnungen v1; `tax_flat` optional spät in v1; Vollmodul v2 |
| A-23 | Portfolio | v2 | v2; eindeutige IDs ab v1, Batch-Summe v1.1 (Vorschlag) |
| A-24 | deterministische Szenario-Sets („Zinsschock“, „Förderstopp“) | S | v1 (als Varianten über Marktpfade), inkl. Set „vorsichtig“ als Ampelbasis |
| A-25 | Validierung und Plausibilisierung mit Warnungen | M | v1 |

---

## 8. Bauplan

### 8.1 Vorgehen (Entscheidung D14)

Gebaut wird durch mehrere KI-Agenten in vier Phasen. **Verträge kommen vor dem Code:** Phase 0 friert die Schnittstellen ein (`docs/spec/00_kernvertraege.md`).
Danach arbeiten Arbeitspakete parallel auf **disjunkten Dateien** gegen diese Verträge und gegen Mocks. Gemeinsame Dateien
(DESCRIPTION, NAMESPACE, Verträge, Registry, Vokabulare, Testhelfer) gehören nur dem Integrator. Fachliche Unklarheiten werden nicht im Code
entschieden, sondern im Vertrag bzw. Glossar festgehalten. Eine Vertragsänderung erhöht die Vertragsversion und wird allen Paketen mitgeteilt.

**Definition of Done je Datei:** deutsche Dokumentation, Tests (Kern ≥ 90 %, gesamt ≥ 80 % Zeilenabdeckung), Vertragstests grün,
kein Nicht-ASCII im R-Code (Texte über Label-Kataloge), `R CMD check` ohne ERROR, WARNING oder NOTE, `lintr` sauber, Labels vollständig.

### 8.2 Phase 0: Verträge und Gerüst (seriell, Integrator)

| Inhalt | Abnahmekriterium |
|---|---|
| Paketgerüst, DESCRIPTION (alle absehbaren Imports und Suggests), CI (`R CMD check`, Tests, lintr, covr, `LANG=C.UTF-8`) | `R CMD check` sauber auf dem leeren Gerüst |
| Kernverträge: Szenario-Schema v1, Kontext-API, Zeitraster mit festem Horizontende, Zeilen-, Fluss- und Anlagenobjekte, Instrument-, Aktions-, Steuer- und Kennzahl-Schnittstellen, Vergleichsvertrag (ΔEW_A − ΔEW_B mit Nachschüssen, Sacheinlage Bestandswert), Ergebnisfelder, Vokabulare (inkl. Steuer-Kennzeichnungen), Glossar, Label-Schema | Spezifikation freigegeben; Konstruktoren und Validatoren implementiert und getestet |
| Registry, Label-Lader, Bedingungsklassen, Hilfsfunktionen (Merge, Pfade, Format, Hash, Seed) | Unit-Tests grün |
| Stubs aller exportierten Funktionen mit deutscher Dokumentation | NAMESPACE steht fest |
| Testhelfer: Kontext-Mock, Beispiel-Ergebnisse, Fake-Ziehungen, Vertragstest-Funktion | von allen Paketen nutzbar |
| **Walking Skeleton**: YAML → Build → Run → Print für ein Minimalszenario (Einlagen und Entnahmen, frei definierte Reihe, endfälliges Darlehen, vier Ausgleichsaktionen) | läuft End-to-End und erfüllt die Invariante „Finanzierungssaldo = 0“ |

### 8.3 Phase 1: parallele Module

| Paket | Inhalt | Abnahmekriterien |
|---|---|---|
| WS-A Eingabe | YAML-Lesen mit Zahlenhandlern, Szenario-Schichten, Bibliotheksverweise und Gültigkeitsprüfung, Varianten | Deep-Merge, Löschen per `~`, Verweisketten und Zyklenfehler, Existenzprüfung bei Varianten-Operationen, Herkunft je Wert |
| WS-A2 Excel | Lesen, Schreiben, generierte Vorlage, reduzierte Haushaltsvorlage | Round-Trip YAML → XLSX → identische Liste; Vorlage = frisch generierte Vorlage; Haushaltsvorlage ergibt mit Defaults ein gültiges Szenario; Fehlermeldungen mit Blatt und Zelle |
| WS-B Validierung | Parameter-DSL, vier Prüfebenen, sicherer Ausdrucksauswerter | alle Befunde gesammelt; jede Meldung mindestens einmal ausgelöst; unbekannte Funktionen werden abgewiesen |
| WS-C Sampling | Verteilungen, Prozesse, LHS, Iman-Conover, Cholesky, Reparatur nicht positiv definiter Matrizen, benannte Ströme | statistische Tests aus Memo 04 §9: Momente innerhalb 4 SE, LHS exakt geschichtet, Rangkorrelation ±0,02, Randverteilungen erhalten, globaler RNG unverändert, Prozesse (Erwartungswert, Stationarität, Untergrenze) |
| WS-D Engine | Zeitraster, Wertnormalisierung, Build, Kontext, Periodenschleife, Ausgleichsaktionen, Unterlassungsalternative (inkl. Sacheinlage), Steuer-Hook mit `tax_none`, Option „Habenzins nach Abgeltungsteuer“, Laufzeitprüfungen, Speicherstrategie | Orakel mit Skelett-Instrumenten bzw. Mocks (Kreditzahlungen aus den Fixtures von WS-T, Toleranz 1e-6): Ausgleich, Zinsen, Nachschüsse, nicht äquidistantes Raster mit endfälligem Darlehen; Invarianten I1–I6; Einzellauf = Batch-Lauf; entartete Verteilungen = deterministischer Lauf; Pflichttests der Steuer-Schnittstelle mit Test-Steuermodul (Memo 06 §7.12); 10.000 × 53 Perioden < 1,5 s. Die vollständige Orakel-Suite ist Abnahme der Integration (8.4) |
| WS-E Zahlungsbausteine | Typen nach Katalog 5.6 (auf 2–3 Agenten aufteilbar) | automatischer Vertragstest je Typ (Dimensionen, Vorzeichen, Kennzeichnungen, Vektorisierungs- und Rasterinvarianz) |
| WS-F Kreditinstrumente | Annuitäten-, Raten- und endfälliges Darlehen als Zustandsautomaten | Orakel (b1), (b2), (e) und Test (f); Prüfwerte S1-T7/T8, S5-T4 bis T7 |
| WS-H Ausgabe Basis | S3-Methoden, VoFi-Tabelle, Grafiken, Excel-Export (gegen Beispiel-Ergebnisse) | Snapshots im deutschen Format; Saldo-Formel in Excel; zurückgelesene Werte stimmen |
| WS-T Orakel und Referenz-Engine | CSV-Fixtures aus dem Python-Referenzskript, zusätzliches **Orakel (g)**: zwei Varianten mit unterschiedlichen Nachschüssen (Vergleichsregel 2.5), **skalare Referenz-Engine** (ca. 150 Zeilen, bewusst ein anderer Agent als WS-D), Generator für Zufallsszenarien | Fixtures vollständig; Referenz-Engine reproduziert die Orakel |

### 8.4 Phase 2: Integration und Fachlogik

Der Integrator führt die Pakete in fester Reihenfolge zusammen (D → C → F → E → A → B → A2 → H) und lässt nach jedem Schritt die gesamte Testsuite laufen.
**Abnahme der Integration:** vollständige Orakel-Suite (a)–(g) aus Memo 01 und WS-T inklusive Kennzahlen mit Toleranz 1e-6. Parallel laufen folgende Pakete:

| Paket | Inhalt | Abnahmekriterien |
|---|---|---|
| WS-D2 Kennzahlen | alle Kennzahlen nach D9, mit und ohne Restwert, NA-Begründungen, Renditen per vektorisierter Bisektion, Rendite der Mehrinvestition, Vermögensamortisation mit Restwertpfad, DSCR ab Stabilisierungsjahr (Objekt- und Maßnahmenebene), LTV und Beleihungsauslauf getrennt, Kennzahlen je WE und m², Haushaltskennzahlen je Perspektive | Orakelwerte; Rangidentität der EK-Rendite (R3) mit der Endwertdifferenz; Vergleichsregel mit Orakel (g); Amortisation „dauerhaft“ |
| WS-G Analyse | Simulation, Vergleich (CRN), Sensitivität, allgemeine Zielwertsuche, Entnahme-Äquivalent, Förderzusage als Entscheidungsknoten (bedingte Auswertung), Szenario-Set „vorsichtig“ | identische Varianten ergeben Differenz exakt 0; Tornado in einem Lauf; Standardfehler aus Replikaten; Konvergenzdiagnostik; Auswahl Variante/Ausweichvariante je Lauf entspricht der getrennten Rechnung |
| WS-E2 Expander und Rechtsregeln | Maßnahmen, Wohnungsgruppen (Mietpfad monatlich, Mietrechtshistorie), Förderung (generisch, Stichtag, Degression, Kumulierung, Berechtigungs-Check), Energie bzw. CO₂, Restwert mit Pfad | Rechenbeispiele 1–7 aus Memo 02, Mietpfad-Testfall Memo 02 §2.2, Regeltests aus Memo 07 §6.2 (Stichtag, Boni, Deckel, Kappungen, § 559f, § 5a), Reihenfolgen nach F13 und F14 |
| WS-L Parameterbibliothek | Einträge für Förderung, Recht, Preise, Kosten, Prozesse mit Metadaten | Schema gültig; Pflichtmetadaten vollständig; Qualitätsstufen und Freigaberegel nach 6.5; bekannte Widersprüche zwischen den Memos nach 11.2 aufgelöst (F13–F21) |
| WS-H2 HTML-Bericht | Fach- und Haushaltsmodus, Pflichtinhalte nach Persona (Memo 07 §5.1/5.2), zweistufige Ampel, druckfähige Kurzvorlage, Pflichtsensitivitäten, Hinweise | Bericht und Kurzvorlage rendern für S1 und S4; Rundungs- und Formulierungsregeln des Haushaltsmodus |
| WS-S Referenzszenarien | S1–S5 als YAML mit Prüfwerten S*-T* | alle Prüfwerte erfüllt, mit den Anpassungen nach F13 und F14; qualitative Hypothesen dokumentiert |
| WS-X Steuer (spät, optional) | `tax_flat`; § 35c ist schon in WS-E2 als Förderinstrument, die Abgeltungsteuer-Option schon in WS-D enthalten | `tax_flat` mit Satz 0 ergibt den Vor-Steuer-VoFi; Sperren für Selbstnutzer und befreite Rechtsträger; die Pflichttests der Schnittstelle (Memo 06 §7.12), die seit Phase 1 mit dem Test-Modul laufen, gelten auch für `tax_flat` |

### 8.5 Phase 3: unabhängige Verifikation und Härtung

Die Verifikation übernehmen Agenten, die den geprüften Code nicht geschrieben haben:

| Prüfung | Kriterium |
|---|---|
| Differenztest Referenz-Engine gegen vektorisierte Engine | 200 zufällig erzeugte Szenarien (feste Seeds) stimmen überein |
| Orakel-Suite (a)–(g) inkl. (a3), (b1), (b2), (c1), (c2), (d), (e) | 1e-6 gegen die Skriptwerte, 0,005 gegen die Tabellenwerte |
| Invarianten I1–I6 | für alle Beispielszenarien und alle Läufe einer Simulation mit 2.000 Läufen |
| Referenzszenarien S1–S5 | alle deterministischen Prüfwerte; fachliche Durchsicht der Hypothesen (Abweichungen werden begründet, nicht „wegkalibriert“) |
| Metamorphe Tests | Skalierung aller Beträge um k skaliert den Endwert um k; höhere Miete ⇒ Endwert ≥; höherer Kontokorrentzins ⇒ Endwert ≤; höherer Gaspreis ⇒ Vorteil der WP-Variante steigt; höherer Tilgungszuschuss ⇒ Differenz steigt; Restwert aus ⇒ Endwerte sinken |
| Statistische MC-Tests | Reproduzierbarkeit, Chunk- und Worker-Unabhängigkeit, Stabilität von Median und P5 zwischen Seeds (±1 % bzw. ±2 % bei 10.000 Läufen) |
| Fachprüfung | Bibliothekseinträge und Rechtsregeln gegen Primärquellen durch die fachlich-juristische Prüfung (6.5, Liste 10.2); nicht prüfbare Punkte nach der Freigaberegel |
| Härtung | `R CMD check --as-cran`, Abdeckung, Performance-Benchmarks, deutsche Vignetten (Einführung, Methodik, Wohnungsunternehmen, Selbstnutzer, Monte Carlo, Erweitern) |

Danach folgt v1.1 mit dem Shiny-Viewer.

### 8.6 Verifikationsstrategie im Überblick

| Ebene | Was sie absichert |
|---|---|
| Vertragstests je Typ | Bausteine halten die Schnittstelle ein und sind korrekt vektorisiert |
| Testorakel (Memo 01) | Finanzmathematik und Ausgleichslogik stimmen mit unabhängig gerechneten Lehrbuchbeispielen überein |
| Regelorakel (Memo 02, Memo 07) | Mietrecht, Förderung und CO₂-Aufteilung liefern die von Hand gerechneten Werte |
| Invarianten | Buchhaltungslogik in jedem Lauf (Saldo null, Vermögensfortschreibung, Nichtnegativität, vollkommener Kapitalmarkt) |
| Referenz-Engine | zweite, unabhängige Implementierung findet Vektorisierungsfehler (`max` statt `pmax`) |
| Referenzszenarien S1–S5 | Zusammenspiel aller Module in realistischen Fällen |
| Statistische Tests | Sampler, Korrelationen, Prozesse, CRN, „entartet = deterministisch“ |
| Snapshots | deutsche Ausgaben und Fehlermeldungen bleiben stabil; Änderungen werden bewusst freigegeben |

---

## 9. Referenzszenarien S1–S5

Alle Szenarien starten 2027 (Anträge bis Ende 2026). Beträge sind brutto. Sie dienen als Beispiele für Nutzer, als Integrationstests
mit deterministischen Prüfwerten und als Demonstration der Funktionen. Die Prüfwerte aus Memo 07 gelten mit den Anpassungen nach F13 und F14, die
Szenarioeinstellungen (Habenzins, Preise, Nutzungsdauern) nach F18 und F19. Die qualitativen Ergebnisse sind **Hypothesen** aus Memo 07, die das Werkzeug
bestätigen oder widerlegen soll; nach F20 werden die MC-Hypothesen mit den Prozessen aus Memo 04 neu geprüft.

**S1: Kommunales Wohnungsunternehmen, Sanierung eines MFH (1963, 24 WE, 1.600 m²) auf EH 70 EE gegenüber der Ohnehin-Sanierung, 30 Jahre.**
Die Ohnehin-Variante V1 umfasst Anstrich, Fenster 2-fach und einen neuen Gas-Brennwertkessel (Einbau 2027, damit greift § 5a ab 2028). Die energetische Variante V2 umfasst WDVS, Decken, Fenster 3-fach,
eine WP-Kaskade und KfW 261 mit WPB-Bonus (Tilgungszuschuss 144.400 €). Optional gibt es Nichtstun, EH 55 und Ersatzneubau. *Das Szenario zeigt:* die Ohnehin-Logik
(Modernisierungskosten 874.303,50 € nach Abzug von 39,8 % Ohnehin-Anteil; der Erhaltungsanteil ist hier vereinfachend als Ohnehin-Vollkosten eingegeben,
was die Plausibilitätsprüfung erfüllt), die § 559-Umlage mit Drittmittelabzug (rechnerisch vor Kappungen 53.842,28 €/a nach F14, Teilkappung des
Heizungsanteils auf 0,50 €/m², Gesamtkappe 2 €/m² → 38.400 €/a, per Beschluss warmmietenneutral 21.120 €/a), tilgungsfreie Jahre, Stufenmodell und § 5a,
die Warmmietensicht (V2 „vorher/nachher“ ≈ neutral, gegenüber V1 im ersten Jahr rund +0,18 €/m², weil auch V1 die Heizkosten mit dem neuen Kessel senkt)
und vor allem die **Restwertdominanz**. Maßgebliche Rendite ist die Rendite der Mehrinvestition V2 gegenüber V1; eine EK-Rendite je Variante gibt es nur mit
Bestandswert (2.6). Im Ertragswert enthält der Reinertrag von V1 die Vermieteranteile nach § 5a und an den Bio-Mehrkosten (3.11); die Plausibilitätswerte
des Restwerts aus Memo 07 verschieben sich dadurch etwas. Pflichtsensitivität „mit 2045-Stufe“: Der Kesselersatz 2047 in V1 ist dann eine Wärmepumpe.
Hypothese: Ohne Restwert ist V2 schlechter, mit Ertragswert-Restwert besser. Das Vorzeichen kippt bei einer Restnutzungsdauer von höchstens etwa 18 Jahren oder einem Liegenschaftszins von mindestens etwa 4,5 %. Ohne WPB-Status verliert
V2 126.400 €.

**S2: Kommunales Wohnungsunternehmen, Neubau eines MFH (36 WE, 2.400 m²), 40 Jahre, Bauzeit 2027–2028.** V1 ist EH 55 mit einem KfW-298-Darlehen der
EH-55-Stufe über 3,6 Mio. € (Gesamtinvestition 11,7 Mio. €), V1b dasselbe ohne KfW, V2 EH 40 mit QNG und einem KfW-298-Darlehen über 5,4 Mio. €
(Gesamtinvestition 12,26 Mio. €). Optional gibt es eine Landesförderung als Platzhalter für Tilgungsnachlass und Mietbindung. *Das Szenario zeigt:* Bauphase mit Zahlungsplan
(nicht äquidistantes Raster), Bauzeit- und Bereitstellungszinsen (KG 800, nicht in der DSCR), Anschlussfinanzierung 2037 als zentrales Monte-Carlo-Risiko,
Zielwertsuche, DSCR ab dem Stabilisierungsjahr 2029 und LTV sowie Kontokorrentbedarf (negativer Cashflow nach Kapitaldienst in den ersten Jahren). Die
Verfügbarkeit der EH-55-Stufe ist ein Entscheidungsknoten mit V1b als Ausweichvariante (3.9). Hypothese: Unter den Konditionen 10/2026 ist V1 besser als V2. Ist die
EH-55-Stufe nicht verfügbar, liegt V2 vor V1b. **Die Förderverfügbarkeit zum Antragszeitpunkt ist entscheidend.** Die Break-even-Miete für 4 % EK-Rendite liegt bei
etwa 15–17 €/m².

**S3: Genossenschaft, Heizungstausch Gas → Wärmepumpe + PV 30 kWp (12 WE, 840 m²), 20 Jahre.** V1 ist ein Gas-Brennwertkessel (Ohnehin, ab 2028
§ 5a), V2 eine WP-Kaskade mit PV und KfW 459 (Zuschuss 45.300 €). *Das Szenario zeigt:* § 559e mit der 0,50-€-Kappe (rechnerisch 8.522,60 €/a nach F13,
gekappt 5.040 €/a) und einer per Vorstandsbeschluss niedrigeren Umlage (0,35 €/m²), die § 559f-Prüfung (Testfall Plan-JAZ 2,4 bei einem Vorlauf über 55 °C,
also ohne Ausnahme, mit wählbarer Reihenfolge; der Basisfall V2 mit 55 °C Vorlauf fiele unter die Ausnahme), 0 % USt auf PV, Einspeisevergütung, die
Zwei-Perspektiven-Sicht (Genossenschaft und Mitglieder), die Rendite der Mehrinvestition, den Warnhinweis zu Nebenerlösen der steuerbefreiten Genossenschaft
und den Strompreis bzw. die realisierte JAZ als Treiber. Hypothese: Der Differenz-Endwert ist positiv (+20 bis +60 T€), und die Warmmiete der Mitglieder liegt mit V2
leicht unter der von V1, mit wachsendem Abstand.

**S4: Selbstnutzer, EFH 1975 (140 m²), stufenweise Sanierung nach iSFP gegenüber „Gaskessel behalten“, 25 Jahre.** Die Stufen sind: Wärmepumpe 2027 (KfW 458:
30 % + 16 % + 10 % Einkommensbonus = 15.680 €), Dach und Fenster 2030 und Fassade mit Kellerdecke 2033 (BAFA mit iSFP-Bonus, KfW 358). Die Referenz umfasst Kesselausfall
(Jahr in der Simulation zufällig), Bio-Treppe für den neuen Kessel und Ohnehin-Termine. Der Heizungsersatz 2050 folgt aus dem Ende der Nutzungsdauer des 2030
eingebauten Kessels; die 2045-Stufe wirkt nur in der Pflichtsensitivität. *Das Szenario zeigt:* den Haushaltsmodus, Förderlogik mit Einkommen und
Kindern, Jahresdeckel (alles sofort bringt weniger Förderung), Prebound aus Verbrauchsdaten, Förderunsicherheit nach 2030, die
Belastung je Monat, den Eigenanteil nach Förderung und die Pflichtsensitivität „Habenzins nach Abgeltungsteuer“. Hypothese: Die Wärmepumpe allein ist klar vorteilhaft (P > 90 %). Der Gesamtfahrplan liegt in der Vermögenssicht
nahe null (P etwa 40–60 %) und bringt eine höhere Monatsbelastung während der Kreditlaufzeit.

**S5: Familie, Neubau EFH (140 m²), EH 40 mit KfW 300 gegenüber GModG-Standard (≈ EH 55) mit KfW 297 EH-55-Stufe, 30 Jahre, Bauzeit 03–12/2027.**
*Das Szenario zeigt:* den Berechtigungs-Check (zvE und Kinder; Negativtest bei zvE 105.000 €), Monatsraten je Phase (Prüfwerte 2.350,03 € bzw.
2.096,72 € in den Jahren 1–5), Restschuld bei Ende der Zinsbindung, die Belastungsquote (≈ 38–42 %, Warnung ab 40 %, als Restriktion der Ampel) und das
Zinsänderungsrisiko 2037 als Fächer. Hypothese: EH 40 dominiert, solange KfW 300 erreichbar ist, **wegen der Förderung, nicht wegen der Energiekosten**, die nahezu gleich
sind. Das ist eine kontraintuitive Aussage, die der Bericht erklären muss.

**S6 (Skizze): Kleinvermieter, 6-WE-MFH.** Dieses Szenario ist nur ein Platzhalter. Ohne Ertragsteuern kann das Ergebnis hier irreführen, deshalb wird es erst mit
`tax_flat` bzw. v2 vollständig spezifiziert.

---

## 10. Risiken und Grenzen

### 10.1 Risiken

| Risiko | Wirkung | Gegenmaßnahme |
|---|---|---|
| **Volatilität von Recht und Förderung** (BEG-Reform 21.07.2026, halbjährliche Degression ab 01.02.2027, WP-Förderreform Q1/2027, EEG-Reform 2027, BEHG 2027, ETS 2 ab 2028, GModG-Folgeschritte 2027/2028/2030, Mietrecht II anhängig) | veraltete Parameter führen zu falschen Empfehlungen | versionierte Einträge mit Gültigkeit, Stichtagskalender, Warnungen, Szenario „Förderstopp“ |
| **Ungeprüfte Sekundärquellen** (siehe 10.2) | fehlerhafte Defaults und Prüfwerte | Qualitätsstufen; Primärprüfung vor Freigabe; Prüfwerte an die Bibliotheksversion gekoppelt |
| **Restwertdominanz** bei 30–40 Jahren | das Vorzeichen hängt an Restnutzungsdauer und Liegenschaftszins | Pflichtausweis ohne Restwert, Tornado, kritische Werte, Variation in der Simulation, Ampel höchstens Gelb bei Vorzeichenwechsel |
| **Bewertung von Bestandsobjekten** | ohne Bestandswert sind absolute Endwerte und EK-Renditen je Variante überhöht | Referenz muss eine Gebäudevariante sein; Bestandswert als Sacheinlage, sonst NA; Rendite der Mehrinvestition (2.5, 2.6) |
| **Prebound und Rebound** | überschätzte Einsparungen aus Bedarfsausweisen | Verbrauchsdaten als Basis, Prebound-Faktor, Warnung, wenn der Bedarf den Verbrauch weit übersteigt |
| **Ausklammerung der Ertragsteuern** | Verzerrung bis hin zur Umkehr der Rangfolge bei privaten Vermietern | deutlicher Warnhinweis, Steuer-Hook ab v1, optional `tax_flat`, v2 |
| **Krisenverzerrung 2026** (Energiepreise, Zinsen) | Startwerte veralten schnell | 12-Monats-Mittel, Mean-Reversion, vierteljährliche Pflege |
| **Subjektive Verteilungen und Korrelationen** | scheinbare Objektivität von Wahrscheinlichkeiten | dokumentierte Defaults, Basisfall daneben, MC-Fehler, Sensitivität auf Verteilungsannahmen |
| Doppelzählungen (Instandhaltung gegenüber Ersatzinvestition, Leerstand gegenüber Mietausfallwagnis, Ohnehin doppelt) | verzerrte Vorteilhaftigkeit | Validierungsregeln, klare Kategorien |
| Fehler in Vorzeichen, Ausgleich, Zinskonvention; Vektorisierungsfehler | falsche Entscheidungen | Orakel, Invarianten in jedem Lauf, Referenz-Engine eines anderen Agenten |
| Umfang der Domäne (Scope Creep) | Verzögerung | fester v1-Typkatalog, frei definierte Reihen als Ausweg, Regeln zunächst auf den Bedarf der Referenzszenarien begrenzt |
| Fehlinterpretation durch Laien (Tilgung als Kosten, statische Amortisation) | Fehlentscheidungen | Haushaltsmodus mit getrennter Liquiditäts- und Vermögenssicht, Klartext, Glossar |
| Haftung bzw. Abgrenzung zur Rechts- und Steuerberatung | Nutzer halten Ergebnisse für Beratung | Haftungs- und Steuerhinweis in jedem Bericht, Verweis auf Energieberatung und Förderbank; vor externer Weitergabe juristisch prüfen |
| `openxlsx` im Wartungsmodus | spätere Inkompatibilität | Kapselung in zwei Dateien, Wechsel zu `openxlsx2` vorbereitet |

### 10.2 Ungeprüfte oder unsichere Angaben (Auswahl, vor Freigabe der Bibliothek zu klären)

- BEG-Richtlinien in der Fassung vom 21.07. bzw. 02.09.2026 und Teile des GModG-Volltexts waren nicht maschinenlesbar abrufbar. Mehrere Förderdetails stammen
  aus Sekundärquellen (KfW 458 im Einzelnen, BAFA-Hülle und iSFP-Bonus, Laufzeit der BEG-Richtlinie bis 2030).
- **§ 559f BGB** (JAZ-Schwelle) ist nur in Memo 07 belegt; zu prüfen sind auch der Grenzfall „≥ 2,5“ oder „> 2,5“ und die Ausnahmen. Ebenfalls offen sind
  die Reichweite der 15-%-Pauschale in § 559e bei § 43-Heizungen und ihre Reihenfolge zum Drittmittelabzug (F13), die Zurechnung der Drittmittel zum
  Modernisierungsanteil (F14), §§ 5b und 5d CO2KostAufG (nach Haufe), die Übergangsregel zu § 5a bei Havarie, die Annahme 100 % klimaneutraler Brennstoff
  ab 2045 (Ableitung) und die Reichweite des Nullsteuersatzes nach § 12 Abs. 3 Nr. 1 UStG für PV-Anlagen über 30 kWp.
- Der Status des BEHG-Korridors 2027 ist in den Memos widersprüchlich: Memo 02 nennt den Bundestagsbeschluss vom 15.10.2026 bei ausstehendem Bundesrat, Memo 03 und 07 nennen einen älteren
  Verfahrensstand.
- Die II.-BV-Werte 2026 stammen aus einem Förderbank-Merkblatt. Nicht im Original verifiziert sind außerdem die Grunderwerbsteuersätze (Sek.), die Nutzungsdauern (BNB/VDI aus
  Fachwissen), die EH-Definitionen nach neuem Referenzgebäude, die WPB-Definition, die Staffel der KfW 459 und die Tilgungszuschuss-Verrechnung (Laufzeitverkürzung, Sek.,
  Stand 2024).
- Die zitierten BGH-Urteile zu Erhaltungsanteil und Kombination von § 558 und § 559 sind zu verifizieren. Die Dauer der Kürzung nach § 558 Abs. 5 ist strittig.
- Der Emissionsfaktor für Erdgas (Hs/Hi-Bezug), die ETS-2-Projektionen (Analysten, Sek.) und die Kalibrierung von Zins und Korrelationen beruhen auf kurzen Reihen
  und normativ gesetzten Gleichgewichtsniveaus.

### 10.3 Grenzen des Modells

Das Werkzeug **optimiert keine Finanzierungspolitik**. Die Ausgleichsregeln sind Heuristiken. Es bildet in v1 keine Kündigungsrechte und keine
Vorfälligkeitsentschädigungen ab, auch nicht am Horizont: Restschulden werden dort nominal abgezogen (2.5). Es gibt in v1 keine Unternehmensebene
(Konzernfinanzierung, Zinsschranke, Organschaft), keine HGB-Sicht, keine Mieter-VoFi und keine stündliche Energiesimulation. Ergebnisse gelten nur unter den dokumentierten Annahmen. Sie ersetzen weder Energieberatung noch Förderantragsprüfung,
Rechts- oder Steuerberatung.

---

## 11. Entscheidungen und offene Fragen

### 11.1 Getroffene Entscheidungen (D1–D14)

| Nr. | Entscheidung | Begründung | Quelle |
|---|---|---|---|
| D1 | R-Paket `vofi`, Architektur A: einfache Listen mit S3-Klassen, über Simulationen vektorisierter Kern (alle Zeitreihen als Matrizen N × (T+1)), deterministisch = N = 1, Funktions-Registry | bester Wert in fünf von sechs Kriterien (gewichtet 4,85 gegenüber 3,40 für R6 und 2,85 für Tidy); 10.000 Läufe in 0,12–0,36 s; keine doppelte Implementierung für Einzelrechnung und Simulation; eine Datei je Typ ermöglicht parallele Entwicklung | Memo 05 A1, Memo 04 E1, Memo 01 E10 |
| D2 | Zeitraster als Vektor von Periodenlängen; Standard jährlich; nicht äquidistante Raster ab v1; Module dürfen intern monatlich rechnen und aggregieren | genaue Bauphase bei kompakter Betriebsphase; im Kern kaum Mehraufwand, weil Zinssätze ohnehin Periodenvektoren sind; das Mietrecht braucht Monatslogik. Damit ist der Konflikt zwischen Memo 01 (E7) und Memo 07 (A-02) aufgelöst | Memo 01 E7, Memo 02 §0, Memo 05 R4 |
| D3 | Zinsen nachschüssig auf die Bestände Ende t−1 | nicht zirkulär, vektorisierbar, Lehrbuchstandard; auch die spätere Steuer bleibt rekursiv | Memo 01 E1, Memo 06 §0 |
| D4 | konfigurierbare Ausgleichsketten; Engpass-Regel für Unternehmen `penalty_rate`, für Privatpersonen `equity_call` | die Rangfolge maximiert den Endwert bei Sollzins ≥ Habenzins; Limitverletzungen werden sichtbar; Unternehmen haben Kreditlinien bzw. Cash-Pool, Haushalte schießen aus dem Einkommen nach | Memo 01 E2, §3.2 |
| D5 | v1 **vor Ertragsteuern**; Steuer-Hook mit `tax_none` und Steuer-Kennzeichnungen ab v1, Zeile „Ertragsteuern“ sichtbar mit Vermerk; `tax_flat` optional spät in v1 (aus, für Selbstnutzer und Befreite gesperrt, als Vereinfachung gekennzeichnet); § 35c als Förderinstrument (7/7/6 %, max. 40.000 €, Ausschluss mit BEG); optional Abgeltungsteuer auf Habenzinsen für Privatpersonen; Vollsteuer ab v2 | hohe Komplexität (Einordnung von Maßnahmen, investorenspezifische Daten, befristete Normen, fünf Regime) bei geringer Relevanz für Selbstnutzer und die meisten Wohnungsunternehmen; die Schnittstelle ab v1 verringert das Risiko eines späteren Refactorings, abgesichert durch Pflichttests mit einem Test-Steuermodul (3.12) | Memo 06 §0, §6; Memo 01 E11 |
| D6 | Nicht-Ertragsteuern in v1: Bruttokosten (kein Vorsteuerabzug), 0 % USt auf PV ≤ 30 kWp, Grunderwerbsteuer nach Land, Grundsteuer als Betriebskosten | geringe Komplexität bei teils hoher Relevanz (USt, Grunderwerbsteuer); größere PV-Anlagen auf oder bei Wohngebäuden sind ebenfalls begünstigt und werden über ein Attribut je Anlage erfasst (3.2) | Memo 06 §8 |
| D7 | Eingabe: kanonisches Szenario aus YAML (primär) und Excel-Vorlage; geschichtete Parameterbibliotheken mit Herkunft; Domänenebene über Expander zu Komponenten; Varianten = Basis + Overrides; Stochastik-Overlay | eine Validierung für beide Formate; Nachvollziehbarkeit („woher kommt dieser Zinssatz?“); fachlich natürliche Eingabe bei generischem Kern | Memo 05 A2–A4 |
| D8 | Monte Carlo: LHS in 10 Blöcken, benannte Zufallsströme, Iman-Conover, Cholesky für Prozessschocks, **CRN zwischen Varianten verpflichtend**, Mean-Reversion für Zinsen, Energie und Inflation, CO₂-Szenariokorridore, Bernoulli-Förderzusage, Performance-Gap-Faktor; 1.000 Läufe Vorschau, 10.000 Standard; Risikomaße und Sensitivität (Tornado, Spider, Break-even, Spearman, PRCC, SRC) | reproduzierbar, ehrliche Fehlerschätzung, aussagekräftige Variantenvergleiche (Varianzreduktion Faktor 79 im Prototyp); die Förderzusage vor Vorhabenbeginn wirkt als Entscheidungsknoten mit Ausweichvariante (3.9) | Memo 04 E1–E13 |
| D9 | Primärkennzahl Endwertdifferenz gegenüber der Referenzalternative; dazu Endwert, VoFi-EK-Rentabilität (NA mit Begründung), Entnahme-Äquivalent, Amortisation, DSCR, LTV, Mindestliquidität, kritische Werte, Warmmietenänderung; Haushaltssicht monatliche Belastung bzw. Ersparnis; alles mit und ohne Restwert | die Endwertdifferenz ist immer definiert und additiv; Renditen können undefiniert sein; der Restwert dominiert lange Horizonte | Memo 01 E3–E5, E12; Memo 07 §5 |
| D10 | anhängige Reformen als Schalter (Standard aus); Rechtsstand und Bibliothekseinträge versioniert mit Gültigkeit und Quelle; Warnung bei veralteten Einträgen | keine Spekulation im Standardfall; Reformen bleiben als Szenario rechenbar; Nachvollziehbarkeit | Memo 02 §0, §10 |
| D11 | Umfang v1: ein Gebäude bzw. Projekt mit mehreren Varianten. Portfolio, Kostenmiete II. BV, WEG und gemischte Nutzung in v2. Shiny-Viewer in v1.1. HTML-Bericht (Fach- und Haushaltsmodus) in v1 | Fokus auf eine belastbare Kernrechnung; Shiny erst bei stabiler API | Memo 07 §3.1, Memo 05 §7 |
| D12 | englische Bezeichner, deutsche Nutzertexte über Label-Kataloge; `R CMD check` ohne Befund | Umlaute im R-Code erzeugen eine WARNING (getestet); die Kataloge ermöglichen später weitere Sprachen | Memo 05 A10 |
| D13 | minimale Imports (`yaml`, `openxlsx`), alles Weitere in Suggests | schlanke Installation, stabile Wartung; LHS, Copula und Validierung sind in Base R umsetzbar | Memo 05 A11, §10 |
| D14 | Bau durch KI-Agenten: serielle Phase 0 (Verträge, Stubs, Testhelfer), dann parallele Pakete auf disjunkten Dateien, dann unabhängige Verifikation | Parallelität ohne Merge-Konflikte; Hauptrisiko „Korrektheit des Kerns“ wird durch unabhängige Prüfung adressiert | Memo 05 A14, §12 |

### 11.2 Abgeleitete Festlegungen (Auflösung von Abweichungen zwischen den Memos)

| Nr. | Festlegung |
|---|---|
| F1 | Total-VoFi je Variante ist Standard. Der Differenz-VoFi dient nur der Erklärung. Der Modus „differential“ aus Memo 02 ist ein gekennzeichneter Vereinfachungsmodus. |
| F2 | EK-Rendite: Standard ist die MIRR-Verallgemeinerung (R3), die klassische Formel ist ihr Spezialfall, der Equity-IRR wird ergänzend ausgewiesen. Undefinierte Fälle sind **NA mit Begründungscode**. Der Vorschlag aus Memo 04, −100 % zu setzen, gilt nur als deutlich gekennzeichnete Darstellungsoption in Histogrammen. |
| F3 | Codes für die Wirkung des Tilgungszuschusses nach Memo 01: `shorten_term` (Standard, entspricht der KfW-Formulierung) und `reduce_installment`. |
| F4 | Die Sondertilgungsregel Ü3 ist programmiert, aber standardmäßig aus. Bei Aktivierung gilt ein Puffer und es erscheint ein Warnhinweis. |
| F5 | **Beschlossenes und verkündetes Recht ist Standard**, auch wenn es erst künftig wirkt (§ 5a CO2KostAufG ab 2028, Bio-Treppe ab 2029); für noch nicht am Primärtext geprüfte Regeln gilt die Freigaberegel in 6.5. Nur **anhängige** Verfahren (Mietrecht II) und eigene Ableitungen (2045-Stufe) sind Schalter mit Voreinstellung „aus“. Der BEHG-Korridor 2027 wird als Preisannahme mit Statusvermerk geführt. |
| F6 | Förderwerte: Memo 02 ist maßgeblich. Abweichende Angaben in Memo 03 §12 (KfW 458 mit 20 % Klimageschwindigkeitsbonus und 5 % Effizienzbonus) sind überholt. |
| F7 | Zinsprozess: Vasicek direkt auf den Bauzins (Memo 04: Niveau 3,75 %) ist Standard. Die Zwei-Faktor-Variante (Bundrendite + Spread, Memo 03) ist eine Alternative in der Bibliothek. |
| F8 | CO₂: Die Korridore niedrig/mittel/hoch aus Memo 03 sind Bibliotheksstandard (komonotone Ziehung über alle Jahre). Die Referenzszenarien nutzen ihren eigenen deterministischen Pfad (Memo 07 §4.0). |
| F9 | Perspektiven-Codes nach Memo 02 (`wu_kommunal`, `wu_genossenschaft`, `wu_privat`, `kleinvermieter`, `selbstnutzer`), dazu ein getrenntes Feld für das Steuerregime nach Memo 06. |
| F10 | Validierung ohne `checkmate` (D13) über eine eigene DSL mit deutschen Meldungen. |
| F11 | Erdgasmengen auf Brennwert (Hs) wie in der Abrechnung, Emissionsfaktoren konsistent umgerechnet. Kosten brutto, netto und USt getrennt gespeichert. |
| F12 | Ein DOCX-Bericht ist technisch vorbereitet, die Freigabe folgt in v1.1 (D11 nennt für v1 den HTML-Bericht; die druckfähige Kurzvorlage deckt den Gremienbedarf). 50.000 Läufe sind eine Option für Tail-Kennzahlen. |
| F13 | **§ 559e-Reihenfolge:** U = 0,10 × (0,85 × K − D) nach Memo 02, d. h. die 15-%-Pauschale bezieht sich auf die aufgewendeten Kosten vor Drittmittelabzug; die Lesart aus Memo 07 (0,10 × (K − D) × 0,85) ist als Parameter wählbar. Grundsätze: Rechtsregeln aus Memo 02 gehen Memo 07 vor (Memo 07 §1); bei unklarer Auslegung wählt die Voreinstellung die für den Vermieter vorsichtigere Lesart (niedrigere zulässige Umlage). Folgen für die Prüfwerte: S3-T3 rechnerisch **8.522,60 €/a** (statt 9.202,10 €/a), gekappt und angesetzt unverändert 5.040,00 € bzw. 3.528,00 €/a. S3-T4 gilt für Plan-JAZ 2,4 bei Vorlauf über 55 °C (Ausnahme nicht erfüllt): **1.996,30 €/a** („erst halbieren, dann Drittmittel abziehen“, Default) bzw. **4.261,30 €/a** („erst Drittmittel abziehen, dann halbieren“), beide unter der Kappung. |
| F14 | **Drittmittelzurechnung und Kappungsreihenfolge (§§ 559, 559a):** Zuschüsse, Tilgungszuschuss und Zinsermäßigung werden einheitlich zugerechnet (Parameter „voll“ oder „anteilig“ auf den Modernisierungsanteil); Voreinstellung „voll“ als vorsichtigere Lesart (F13). Der Heizungsanteil (§ 555b Nr. 1a) wird zuerst auf 0,50 €/m² gekappt, danach gilt die Gesamtkappe. Folgen: S1-T4 „rechnerisch vor Kappungen“ = (874.303,50 − 144.400) × 8 % − 1.300.000 × 0,35 % = **53.842,28 €/a** (2,80 €/m²·Monat; Memo 07: 55.651,59 €/a mit anteiliger Zinsermäßigung); S1-T5 und S1-T6 unverändert. WS-S ergänzt einen Prüfwert S1-T4a für die Umlage nach Teilkappung des Heizungsanteils; in S1 bindet die 2-€-Kappe. |
| F15 | **Kreditbeträge** werden im Basisfall bestimmt und sind in allen Läufen fest (Zusage- bzw. Vertragsbetrag). Die Regel aus Memo 05 §5.5, nach der das Darlehen bei Kostenüberschreitung im selben Lauf steigt, entfällt. Mehrkosten laufen über Ausgleich oder optionale Nachfinanzierung; der Tilgungszuschuss bezieht sich auf den festen Zusagebetrag, höchstens auf den abgerufenen Betrag. |
| F16 | **Horizont:** Das Horizontende ist ein festes Kalenderdatum (Bewertungsstichtag + Horizont in Jahren) für alle Varianten und Läufe. „Ab Fertigstellung“ (Memo 01 §5.5, §7 Nr. 6) gilt nicht; ein Bauzeitverzug verschiebt nur Mietbeginn, Bauzeitzinsen und Nutzungsjahre. |
| F17 | **Vergleichsregel:** Varianten werden über ΔEW_A − ΔEW_B verglichen, jede gegen ihre eigene Unterlassungsalternative mit ihren eigenen Nachschüssen (Memo 05 §6.6, Memo 01 K11). Ungleiche Nachschüsse sind kein Vergleichbarkeitsfehler. Bei Bestandsobjekten ist die reine Unterlassungsalternative als Referenz unzulässig; der Bestandswert ist eine Sacheinlage (2.6). |
| F18 | **Habenzins je Perspektive:** Wohnungsunternehmen (kommunal, privat) Kalkulationszins mit Vorbelegung 3,5 % (= Zielrendite, A4), Genossenschaft 2,0 % (= Mindestverzinsung), Privatpersonen 2,5 %. Im Monte Carlo wird der Abstand zum Zinspfad so gesetzt, dass der Startwert dem deterministischen Wert entspricht. Die Referenzszenarien S1–S3 behalten den Habenzins aus Memo 07 §4.0 (2,0 %) als ausdrückliche Szenarioeinstellung; die Pflichtsensitivität zeigt den Unterschied. |
| F19 | **Bibliotheks-Defaults** nach Memo 03 (mit Quelle und Qualitätsstufe): Energiepreise (Erdgas EFH 12,0 ct, MFH 11,2 ct, Haushaltsstrom 37,5 ct, WP-Strom 26,0 ct je kWh; die Werte in 3.8 sind Beobachtungen), Nutzungsdauern (u. a. Gas-Brennwertkessel 18 statt 20 J., Wechselrichter 12 statt 13 J., Fenster 40/50 statt 35/45 J., Flachdachabdichtung 30 statt 25 J., Heizkörper 40 statt 30 J. in Memo 02), Baunebenkosten KG 700 20 % (Memo 02: 18 %). Risikozuschlag Unvorhergesehenes 10 % (Memo 02). Die Referenzszenarien behalten ihre eigenen Preise (z. B. Erdgas EFH 12,50 ct, WP-Strom EFH 24 ct) und Nutzungsdauern aus Memo 07 als Szenarioeinstellung. |
| F20 | **Prozesse im Monte Carlo:** Die Mean-Reversion-Prozesse aus Memo 04 (Gas σ 8 %, Strom σ 4 %, Schockkorrelation 0,5; Inflation μ ~ N(2,0 %; 0,3–0,5 Pp.)) gelten auch für S1–S5. Die Random-Walk-Defaults aus Memo 07 §4.0 (Gas σ 12 %, Strom σ 8 %, ρ 0,6; Inflation N(2,2 %; 0,6 Pp.)) entfallen. Die MC-Hypothesen aus Memo 07 (z. B. S4: P > 90 %) werden damit neu geprüft. |
| F21 | **LHS-Replikate:** stets 10 Replikate zu je N/10 Läufen (D8, Memo 04 E6); N muss durch 10 teilbar sein, Chunks sind Vielfache von N/10. Die feste Blockgröße von 1.000 Läufen aus Memo 05 §6.3 entfällt; damit ändern sich die Ziehungen, wenn N geändert wird (Memo 04). |

### 11.3 Offene Fragen an den Auftraggeber

Bis zur Antwort gilt die genannte Annahme. Priorität **A** heißt: vor Phase 0 zu klären, weil die Antwort Verträge oder Engine-Defaults betrifft. **B** heißt: vor Phase 2 zu klären
(Fachregeln, Defaults). **C** heißt: vor der Freigabe bzw. später zu klären.

| Nr. | Frage | Annahme bis zur Antwort | Memos |
|---|---|---|---|
| A1 | Welche Zielgruppen haben Priorität in v1? Sind private Vermieter eine Hauptzielgruppe, und soll `tax_flat` damit gebaut werden? | alle fünf Personas; Fach- und Haushaltsmodus in v1; Kleinvermieter und Kapitalgesellschaften ohne erweiterte Kürzung (`wu_privat`) mit Steuerwarnhinweis; `tax_flat` (für Kapitalgesellschaften als Satz-Schalter nutzbar) als letztes Paket von v1, wenn Kapazität bleibt | 02, 06, 07 |
| A2 | Konto-Defaults je Perspektive (Habenzins, Kontokorrentzins, Limit, Mindestliquidität, Strafzinsaufschlag) | WU (kommunal, privat): Habenzins = Kalkulationszins, Vorbelegung 3,5 % (= Zielrendite; Begründung 2.6), Pflichtsensitivität mit 2,0 % (reine Liquiditätsanlage) und mit dem vermiedenen FK-Zins (4,0 %); Genossenschaft: Habenzins 2,0 % (= Mindestverzinsung); WU und Genossenschaft: Kontokorrent 5,5 %, Limit als Warnschwelle, darüber `penalty_rate` (Aufschlag als Parameter, Vorschlag +2 Pp.); privat: Habenzins 2,5 %, Zwischenfinanzierung 6,0 %, Limit 0 €, darüber Nachschuss mit Warnung bei Überschreiten der Sparfähigkeit; Mindestliquidität 0; im Monte Carlo Abstand zum Zinspfad passend zum Startwert (F18) | 01, 03, 07 |
| A3 | Standardhorizont und Restwertmethode je Anwendungsfall; Verkaufskosten | Horizontende als festes Kalenderdatum für alle Varianten und Läufe (F16): Bewertungsstichtag + 30 J. bei Sanierung (25–30), + 40 J. beim Neubau einschließlich Bauzeit; Ertragswert bei Vermietung, Komponenten-Zeitwert bei Einzelmaßnahmen, Sachwert bzw. Marktwertfortschreibung beim Selbstnutzer-EFH; Verkaufskosten 3 %; immer auch ohne Restwert | 01, 02, 07 |
| A4 | Schwellen und Hürden je Perspektive | Zielrendite WU 3,5 %, Mindestverzinsung Genossenschaft 2 %, DSCR 1,2 ab Stabilisierungsjahr (erstes volles Betriebsjahr), Belastungsquote 40 %, Warmmietenanstieg 0,50 €/m²; Ampel zweistufig (1.4) mit 70 % / 40 % und Restriktionsschwelle P(Verletzung) 30 % | 04, 07 |
| A5 | Paketname, Lizenz, Veröffentlichung (intern oder CRAN) | `vofi`, interne Nutzung über Git, Lizenzfeld vorläufig proprietär (`file LICENSE`), keine CRAN-Einreichung | 05 |
| A6 | Codes für Fachbegriffe deutsch (ASCII, z. B. `selbstnutzer`), Schlüssel englisch? | ja; Perspektive und Steuerregime getrennt (F9) | 05 |
| A7 | Sollen gesetzlich erzwungene Ereignisse (Bio-Treppe, § 5a, 2045) in Referenzvarianten automatisch wirken? | Bio-Treppe und § 5a ja, automatisch aus der Bibliothek, sobald Heizungsart und Einbaudatum gesetzt sind; die 2045-Stufe (Abl.) ist ein Szenario-Schalter mit Voreinstellung „aus“ und Pflichtsensitivität (3.8); bauteilbedingte Anforderungen (Dämmpflicht bei Erneuerung) gibt der Nutzer ein, und das Werkzeug warnt | 02, 07 |
| A8 | Wie werden Haushalte in v1 bedient (Betriebsmodell)? | Bedienung durch Mittler (Energie- oder Förderberatung, Wohnungsunternehmen, Verbraucherberatung); der Haushalt erhält den Bericht; reduzierte Haushaltsvorlage in Excel (5.3); eigenständige Nutzung durch Laien erst mit dem Szenario-Editor (v2) | 05, 07 |
| A9 | Bewertung von Bestandsobjekten: Bestandswert als Sacheinlage und Bestandsdarlehen als Eingabe? | ja (2.6, 3.10): Bestandswert dringend empfohlen, ohne ihn ist die absolute EK-Rendite NA und die Rendite der Mehrinvestition maßgeblich; Bestandsdarlehen optional, in allen Gebäudevarianten identisch; die reine Unterlassungsalternative ist als Referenz unzulässig | 01, 07 |
| B1 | Mietrechtliche Auslegungen: Zurechnung von Zuschüssen, Tilgungszuschuss und Zinsermäßigung (§ 559a) anteilig oder voll? Reihenfolge von Pauschale und Drittmittelabzug bei § 559e? Reihenfolge bei § 559f? 15-%-Pauschale bei § 43-Heizung? Dauer der Kürzung nach § 558 Abs. 5? | einheitliche Zurechnung, Voreinstellung voll (vorsichtigere Lesart, F14; Memo 07 rechnet die Zinsermäßigung anteilig); § 559e: Pauschale vor Drittmittelabzug (F13); § 559f „erst halbieren, dann Drittmittel abziehen“; Teilkappung des Heizungsanteils vor der Gesamtkappe; keine Pauschale bei § 43-Heizung; Kürzung bei Zuschüssen 12 Jahre, bei Darlehen für die Dauer der Zinsbindung; alles als Parameter | 02, 07 |
| B2 | Förderauslegung: iSFP-Bonus nur oberhalb der Schwelle? Staffel KfW 459 = 458? | iSFP-Bonus nur auf den übersteigenden Betrag; Staffel wie 458; Tilgungszuschuss als Laufzeitverkürzung | 02, 07 |
| B3 | Genossenschaft: Umlage nach §§ 559/559e mit Beschlussbegrenzung oder freie Entgelterhöhung? Verrechnung von PV-Strom an Mitglieder? | §§ 559/559e mit Beschlussparameter; PV-Strom an Mitglieder 0 ct (nur Einspeisung bzw. Eigenverbrauch Allgemeinstrom) | 07 |
| B4 | Abgeltungsteuer auf Habenzinsen bei Privatpersonen standardmäßig an? | aus (reiner Vor-Steuer-VoFi, D5); die Option gehört aber zum Pflichtumfang von v1 (Kontomodell), ist für Selbstnutzer und Kleinvermieter Pflichtsensitivität, und der Bericht nennt die Fehlerrichtung (3.12); Memo 06 empfiehlt „an“ für Selbstnutzer | 06 |
| B5 | Wer verantwortet die Default-Verteilungen? Sind Presets gewünscht? | Defaults aus Memo 03/04 mit Quelle und Qualitätsstufe; fachliche Verantwortung beim Auftraggeber; Szenario-Set „vorsichtig“ in v1 (Ampelbasis), weitere Presets in v1.1 | 04, 07 |
| B6 | CO₂-Szenarien: Pfade, Gewichte, nominal oder real? | Korridore aus Memo 03, nominal, komonotone Dreiecksziehung (mittel = Modus) | 03, 04 |
| B7 | Performance Gap: Strukturmodell oder einfacher Realisierungsfaktor? | Strukturmodell (Faktoren vorher und nachher); mit Verbrauchsdaten nur der Nachher-Faktor; Verbrauchsdaten dringend empfohlen | 04 |
| B8 | Energiepreis-Startwert: 12-Monats-Mittel oder Spotpreis? | 12-Monats-Mittel mit Mean-Reversion; Spotpreis als Alternative | 03 |
| B9 | Kostenrisiken zweier Varianten: dasselbe Risiko oder getrennte Risiken? | gleiches Risiko = gleicher Name; verwandte Risiken getrennt mit Rangkorrelation 0,7 | 04 |
| B10 | Regionale Defaults bzw. Lage-Presets? | generisch (Mittelstadt); Lage-Presets aus Memo 03 als optionale Bibliothek | 03, 07 |
| B11 | Fallarten in v1 (Grundstückskauf + Neubau, Bestandskauf + Sanierung)? | alle Fallarten zahlungsseitig inklusive Grunderwerbsteuer; steuerliche Folgen (anschaffungsnahe Herstellungskosten) erst in `tax_flat` bzw. v2 | 06 |
| B12 | Umfang des Förderrisikos | Bernoulli-Zusage; bei Zusage vor Vorhabenbeginn als Entscheidungsknoten mit Ausweichvariante und bedingter Auswertung (3.9), bei späteren Stufen und für die Verfügbarkeit nach 2030 (p = 0,7) als einfache Ziehung; Kürzung bzw. Rückforderung des Tilgungszuschusses und Auszahlungsverzug als Parameter (Voreinstellung 0); deterministisches Szenario-Set „Förderstopp“ | 02, 04, 07 |
| B13 | Soziale Wohnraumförderung für bestimmte Länder? | generisch (Tilgungsnachlass, Mietobergrenze); Belegungsbindung und landesspezifische Einträge in v2 | 02 |
| B14 | Wer übernimmt die fachlich-juristische Prüfung der Rechtsregeln und Förderauslegungen, und gilt die Freigaberegel? | der Auftraggeber benennt eine Stelle mit Rechts- bzw. Förderfachkunde oder beauftragt extern; Umfang Liste 10.2; Freigaberegel und Aufwandsschätzung nach 6.5 | 02, 07 |
| C1 | Wer pflegt die Bibliotheken, in welchem Rhythmus? | Fachstelle beim Auftraggeber nach Kalender 6.3; das Werkzeug warnt bei veralteten Einträgen | 02, 05, 07 |
| C2 | Gibt es vorhandene Excel-VoFis aus der Praxis als zusätzliche Testorakel? | nein, nur Orakel aus Memo 01 und Referenzszenarien | 05 |
| C3 | Berichtslayout, Corporate Design, Pflichtkennzahlen (Covenants)? | neutrales Layout, Kennzahlen nach D9 | 05 |
| C4 | Betrieb der Shiny-App (lokal, Server), Vertraulichkeit, akzeptable Rechenzeiten | lokal; Abnahmekriterium bleibt 5.7 (10.000 Läufe × 50–53 Perioden < 1,5 s); Zielwerte für den Shiny-Viewer: Vorschau mit 1.000 Läufen unter 0,2 s, Standard unter 1 s | 04, 05 |
| C5 | `openxlsx` oder `openxlsx2`? | `openxlsx` (D13), gekapselt | 05 |
| C6 | Reicht die abgeleitete Warmmietensicht, oder wird eine Mieter-VoFi gewünscht? | Warmmietensicht reicht, Mieter-VoFi in v2 | 01, 04, 07 |
| C7 | Optionale Varianten (S1-V4 Ersatzneubau, S2-V3 Landesförderung) als Pflichttests? | nur als Beispiele | 07 |
| C8 | Reale Kennzahlen zusätzlich ausweisen? | nominal primär, Kaufkraftsicht umschaltbar | 03, 04 |
| C9 | Tail-Abhängigkeit (t-Copula) und Stresstests | v1 Gauß bzw. Iman-Conover und feste Stresspfade; t-Copula in v2 | 04 |
| C10 | Mischnutzung, Mieterstrom, Gewerbeeinheiten | v2; v1 gibt eine Warnung aus, Mieterstrom ist nur als frei definierte Zahlungsreihe möglich (3.5) | 03, 06 |
| C11 | Gesellschafterebene (Ausschüttungen) außerhalb des Scopes? | ja, außerhalb | 06 |
| C12 | Umfang des sicheren Ausdrucksauswerters | Förderbedingungen und Mengenformeln (z. B. Fläche × €/m²) | 05 |

---

## Anhang A: Glossar

| Begriff | Erläuterung |
|---|---|
| Amortisation (dynamisch) | erstes Jahr, ab dem das Vermögen der Variante dauerhaft über dem der Referenz liegt; „ohne Restwert“ oder als Vermögensamortisation mit Restwertpfad |
| Anschlussfinanzierung, Anschlusszins | Weiterfinanzierung der Restschuld nach Ende der Zinsbindung zum dann gültigen Zins |
| Ausgleichsregel | feste Rangfolge, nach der Überschüsse bzw. Defizite einer Periode über Kontokorrent, Anlage oder Nachschuss ausgeglichen werden |
| Ausweichvariante | Variante, die gerechnet wird, wenn eine vor Vorhabenbeginn beantragte Förderung nicht zugesagt wird (Entscheidungsknoten) |
| Belastungsquote | (Kreditrate + Wohnnebenkosten) / Haushaltsnettoeinkommen |
| Beleihungsauslauf, LTV | Darlehen / Beleihungswert (Marktwert abzüglich Sicherheitsabschlag) bzw. Schulden / Marktwert |
| Bestandswert (Sacheinlage) | Verkehrswert eines Bestandsgebäudes zum Bewertungsstichtag, abzüglich Bestandsdarlehen als zahlungsunwirksame Einlage in t = 0 gebucht |
| Bio-Treppe | Mindestanteil biogener Brennstoffe für neu eingebaute fossile Heizungen nach § 43 GModG (10 % 2029 … 60 % 2040) |
| CRN (Common Random Numbers) | alle Varianten werden auf denselben simulierten Zukünften gerechnet |
| DSCR, ICR | Kapitaldienstdeckungsgrad (NOI / planmäßiger Kapitaldienst, ab Stabilisierungsjahr), Zinsdeckungsgrad |
| EE-, NH-Klasse, WPB, SerSan | BEG-Merkmale: ≥ 65 % erneuerbare Wärme; Qualitätssiegel Nachhaltiges Gebäude; Worst Performing Building (Klasse H bzw. Altbau weitgehend unsaniert); serielle Sanierung |
| Endwert, Endwertdifferenz | Vermögen (Guthaben − Schulden, inkl. Restwert) am Horizont; Differenz zur Referenz, die Hauptkennzahl |
| Entnahme-Äquivalent | jährlich zusätzlich entnehmbarer Betrag, bei dem man am Ende genauso gut steht wie in der Referenz |
| Expander | übersetzt fachliche Eingaben (Maßnahmen, Wohnungsgruppen, Förderung) in Zahlungskomponenten |
| Fach- bzw. Haushaltsmodus | Berichtsvarianten für Wohnungswirtschaft bzw. Privatpersonen |
| Herkunft (Provenienz) | Nachweis je Wert: aus welcher Datei, welchem Bibliothekseintrag oder welcher Excel-Zelle er stammt |
| iSFP | individueller Sanierungsfahrplan, Voraussetzung für Bonus und höhere Förderhöchstkosten |
| Iman-Conover, Cholesky | Verfahren, um Rangkorrelationen zwischen gezogenen Größen bzw. korrelierte Zeitreihenschocks zu erzeugen |
| JAZ | Jahresarbeitszahl der Wärmepumpe (Wärme / Strom) |
| Kappungsgrenze | Obergrenze für Mieterhöhungen (§ 558: 20 % bzw. 15 % in 3 J.; § 559: 3 bzw. 2 €/m² in 6 J.; Heizung 0,50 €/m²) |
| Kontokorrent | kurzfristige Kreditlinie, die Defizite deckt (Unternehmen: Cash-Pool bzw. Betriebsmittellinie; privat: Dispo bzw. Zwischenfinanzierung) |
| LHS | Latin Hypercube Sampling, eine geschichtete Zufallsstichprobe mit gleichmäßiger Abdeckung |
| Liegenschaftszins, Restnutzungsdauer | Kapitalisierungszins und verbleibende wirtschaftliche Nutzungsdauer im Ertragswertverfahren |
| Mean-Reversion (Vasicek, AR(1)) | Zeitreihe, die nach Schocks zu einem langfristigen Niveau zurückkehrt |
| Modernisierungsumlage | Mieterhöhung nach §§ 559 ff. BGB wegen Modernisierung |
| Nachschuss (`equity_call`) | endogene Eigenkapitaleinlage, wenn das Kontokorrentlimit nicht reicht |
| Ohnehin-Kosten | Kosten, die ohne die energetische Maßnahme ohnehin anfallen würden (Instandsetzung) |
| Overlay (Stochastik) | getrennte Spezifikation der Unsicherheiten, die auf deterministische Eingaben zielt |
| Plan-JAZ, realisierte JAZ | JAZ aus dem Nachweis nach VDI 4650 vor Inbetriebnahme (steuert § 559f) bzw. im Betrieb erreichte JAZ (steuert Strombedarf, in der Simulation unsicher) |
| Prebound, Rebound | realer Verbrauch unsanierter Gebäude liegt unter dem Bedarf; nach der Sanierung steigt der Verbrauch über den Bedarf |
| Registry | Verzeichnis aller Bausteintypen; neue Typen werden registriert, ohne den Kern zu ändern |
| Rendite der Mehrinvestition | Habenzins, bei dem die Endwertdifferenz gegenüber der Referenz null wird |
| Restwert, Restwertpfad | Wert des Objekts bzw. der Maßnahme am Horizont, eigene Zeile, Ausweis mit und ohne; der Pfad RW_t gibt den Wert je Periode an |
| Stabilisierungsjahr | erstes Jahr, ab dem DSCR und ICR ausgewiesen werden (Standard: erstes volles Betriebsjahr nach Fertigstellung) |
| Steuer-Hook | Schnittstelle in der Periodenschleife, an die Steuermodule andocken (v1: `tax_none`) |
| Stufenmodell (CO2KostAufG) | Aufteilung der CO₂-Kosten nach kg CO₂/(m²·a) in zehn Stufen |
| Szenario-Set „vorsichtig“ | deterministisches Szenario, in dem die fünf einflussreichsten Treiber auf ihrem ungünstigen P10- bzw. P90-Wert stehen; Basis der Ampel ohne Monte Carlo |
| Tilgungszuschuss | Förderbetrag, der die Darlehensschuld zahlungsunwirksam mindert |
| Tornado, Spider, PRCC, SRC | Darstellungen bzw. Maße, wie stark einzelne Eingaben das Ergebnis beeinflussen |
| Unterlassungsalternative | Referenz „nicht investieren, Eigenkapital zum Habenzins anlegen“; bei Bestandsobjekten nicht als Referenz zulässig, aber intern für die Vergleichsregel genutzt |
| VoFi | Vollständiger Finanzplan nach Grob: alle Zahlungen einer Investition je Periode, mit Finanzierung, Anlage und Ausgleich |
| VoFi-EK-Rentabilität | Verzinsung des eingesetzten Eigenkapitals bis zum Endwert (MIRR-Logik bei mehreren Einlagen) |
| Warmmiete | Nettokaltmiete + Umlage + Heiz- und Warmwasserkosten der Mieter + sonstige Betriebskosten; Änderung „vorher/nachher“ und „gegenüber Referenz“ |

## Anhang B: Verzeichnis der Recherche-Memos (Stand 25.10.2026)

| Nr. | Datei | Thema | Kernaussagen für dieses Konzept |
|---|---|---|---|
| 01 | `docs/recherche/01_vofi_methodik.md` | VoFi-Methodik, Finanzmathematik, Kennzahlen, Testorakel (a)–(f) mit Python-Referenzskript | nicht zirkuläre Vorwärtsrekursion, Ausgleichsrangfolge, Endwertdifferenz als Primärkennzahl, MIRR-Rendite, Invarianten I1–I6 |
| 02 | `docs/recherche/02_wohnungswirtschaft_recht_foerderung.md` | Domänenmodell, Mietrecht, CO2KostAufG, GModG, Förderprogramme, generisches Fördermodell, Restwert | versionierte Rechtsstände, Monatslogik für Mietrecht und Bauphase, Förderschema, Rechenbeispiele 1–7 |
| 03 | `docs/recherche/03_parameter_defaults.md` | Default-Parameter mit Quellen, Qualitätsstufen und Verteilungen | Energiepreise 2026, CO₂-Korridore, Zinsen, Baukosten, Bewirtschaftung, Leerstand, YAML-Vorlage |
| 04 | `docs/recherche/04_monte_carlo.md` | Monte-Carlo-Methodik, Prototyp und Benchmarks | eine vektorisierte Engine, LHS, benannte Ströme, CRN, Sensitivität, Validierungstests |
| 05 | `docs/recherche/05_r_architektur.md` | R-Architektur, Eingabeformat, Registry, Reporting, Tests, Arbeitspakete | Architektur A, Schichtenmodell, Excel-Vorlage, Testpyramide, Phasenplan |
| 06 | `docs/recherche/06_steuern_komplexitaet.md` | Ertragsteuern: Komplexitätsbewertung, Schnittstelle, Nicht-Ertragsteuern | v1 vor Steuern mit Hook, `tax_flat` optional, § 35c, USt/GrESt/Grundsteuer |
| 07 | `docs/recherche/07_use_cases_referenzszenarien.md` | Personas, Adaptivitätsanforderungen A-01–A-25, Referenzszenarien S1–S5, Berichtsanforderungen | Fach- und Haushaltsmodus, Prüfwerte, Verständlichkeitsregeln, Restwertdominanz |
| – | `docs/recherche/prototypen/` | Prototypen (Referenzskript VoFi, Monte Carlo, Architektur-Benchmarks) | Grundlage der Performance- und Testaussagen |
| – | `docs/spec/00_kernvertraege.md` | verbindliche technische Kernverträge (in Arbeit) | regelt Datenstrukturen, Schlüssel und Schnittstellen; geht diesem Konzept in technischen Details vor |

## Anhang: Review-Protokoll

Review-Runde 1 mit zwei Prüfperspektiven: **P** = Praxis (Wohnungswirtschaft, Bank, Gremien), **L** = Vollständigkeit aus Laiensicht. Jeder Befund wurde
am Konzept und an den Recherche-Memos geprüft. Ergebnis: 48 Befunde, davon 45 übernommen, 3 teilweise übernommen, keiner abgelehnt (alle Befunde ließen
sich am Dokument bzw. an den Memos bestätigen). Die verbindlichen Entscheidungen D1–D14 bleiben unverändert; wo ein Befund sie berührt, ist die
Umsetzung D-konform (P3: D8, P18: D6, L8: D5). **Für die Spezifikation `docs/spec/00_kernvertraege.md` folgen daraus:** Vergleichsregel (F17), festes
Horizontende (F16), Sacheinlage Bestandswert und Bestandsdarlehen (2.6, 3.10), feste Kreditbeträge (F15), Plan- und realisierte JAZ (3.5), Ausweichvariante
der Förderzusage (3.9), Restwertpfad RW_t (3.11) und LHS-Replikate N/10 (F21).

| Nr. | Schwere | Abschnitt | Befund (kurz) | Ergebnis | Begründung bzw. Umsetzung |
|---|---|---|---|---|---|
| P1 | major | 2.5, 1.2 (a), 9 S1 | Bestandswert fehlt; EK-Rendite und ΔEW gegen die Unterlassung sind bei Bestandsobjekten überhöht | übernommen | Bestandswert als Sacheinlage (sonst EK-Rendite NA), Rendite der Mehrinvestition, Referenz muss Gebäudevariante sein (2.5, 2.6, 6.2, A9) |
| P2 | major | 2.6, A2, A4 | Habenzins WU 2,0 % widerspricht 2.6; Ampel grün unter Zielrendite | übernommen | Habenzins WU = Kalkulationszins (3,5 %), Genossenschaft 2,0 %, Pflichtsensitivität, Lücke zur Zielrendite im Bericht (2.6, A2, F18) |
| P3 | major | 4.2, 3.9 | Bernoulli-Zusage mischt „gebaut trotz Ablehnung“ mit Umplanung; Mietrechtsfolgen und Restrisiken fehlen | übernommen | Entscheidungsknoten mit Ausweichvariante und bedingter Auswertung, Bernoulli-Ziehung bleibt (D8); Mietrecht mit tatsächlicher Förderung; Kürzung und Verzug als Parameter (3.5, 3.9, 4.2, B12) |
| P4 | major | 3.5, 8.4, 11.2 | § 559e: Reihenfolge Pauschale/Drittmittel widersprüchlich, Orakel gleichzeitig unerfüllbar | übernommen | F13: Formel aus Memo 02 als Default (Rechtsmemo geht vor, vorsichtigere Lesart), S3-T3/T4 neu; Voraussetzung „Drittmittel in Anspruch genommen“ und Rückfall auf § 559 ergänzt |
| P5 | major | 3.5, 4.2, 9 S3 | stochastische JAZ steuert § 559f; S3-Testfall widerspricht der 55-°C-Ausnahme | übernommen | Plan-JAZ (deterministisch) für § 559f, realisierte JAZ für Strom und Warmmiete; Testfall mit Vorlauf über 55 °C; Grenzfall „≥/>“ in 10.2 |
| P6 | major | 2.5, 3.5, 4.5, A4 | Bezugsbasis der Warmmietenänderung undefiniert | übernommen | zwei Kennzahlen (vorher/nachher, gegen Referenz), nur Mieteranteil der Heizkosten, Beschlussumlage im Basisfall bestimmt und fest, P(ΔWarmmiete > Schwelle) und Fächer |
| P7 | major | 2.5, Glossar, 6.2 | DSCR in der Bauphase, Bestandsdarlehen fehlen, LTV = Beleihungsauslauf | übernommen | DSCR ab Stabilisierungsjahr, Bauzeitzinsen als KG 800, Bestandsdarlehen als Eingabe, Objekt- und Maßnahmenebene, LTV und Beleihungsauslauf getrennt mit Restwertpfad |
| P8 | major | 3.4, 3.11 | Komponenten-Restanteil zusätzlich zum Ertragswert zählt doppelt | übernommen | nur bei Komponenten-Zeitwert; beim Ertragswert nur als gekennzeichnetes objektspezifisches Merkmal mit Validierungswarnung |
| P9 | major | A7, F5, 3.8 | 2045-Stufe (Abl.) wirkt automatisch und begünstigt WP-Varianten | übernommen | Szenario-Schalter „aus“ mit Pflichtsensitivität; A7 auf Bio-Treppe und § 5a beschränkt; S1 und S4 konsistent gemacht |
| P10 | major | 3.10, 4.2 | Kreditbetrag je Lauf setzt Voraussicht voraus | übernommen | F15: Beträge im Basisfall fest, optionale Nachfinanzierung, Tilgungszuschuss auf den festen Zusagebetrag |
| P11 | major | 1.4 | Ampel ohne Restwertregel, ohne Restriktionen, ohne v1-Szenario | übernommen | zweistufige Ampel: Gelb bei Vorzeichenwechsel ohne Restwert, Restriktionen als K.-o.-Kennzeichen, Szenario-Set „vorsichtig“ ab v1 |
| P12 | major | 5.5, 7.1, F12 | keine Gremienvorlage in v1 | teilweise | Kurzvorlage (2–4 Seiten, Print-CSS, PDF über den Browser) in v1 übernommen; DOCX bleibt v1.1, begründet mit eigener Vorlage und Layouttests |
| P13 | major | 2.5, 9, 1.3 | kritische Werte nur für ΔEW = 0 | übernommen | allgemeine Zielwertsuche (Zielrendite, DSCR, Liquidität, Kostendeckung, Warmmiete); RND, Liegenschaftszins, Restwertfaktor ergänzt |
| P14 | minor | 0, 3.12 | HGB-Sicht nicht erwähnt | übernommen | in „Bewusst nicht in v1“ und 7.1; indikative Aufteilung „Aufwand / aktivierungsfähig“ ab v1.1 |
| P15 | minor | 3.5 § 559 | Zinsermäßigung wirkt scheinbar auf die Kostenbasis | übernommen | Formel als 8 % × (Kosten − Erhaltung − Zuschüsse) − Zinsermäßigung gefasst |
| P16 | minor | B1, 3.3, 2.6 | asymmetrische Drittmittelzurechnung; Erhaltungsanteil = Ohnehin-Vollkosten | teilweise | einheitliche Zurechnung (Default voll, F14), Verschleißmethode als Standard, Plausibilitäts- statt Gleichheitsprüfung; S1 behält die vereinfachte Eingabe als dokumentierte Szenarioannahme |
| P17 | minor | 9 S1, S1-T4 | Teilkappung des Heizungsanteils fehlt | übernommen | Teilkappung vor Gesamtkappe (3.5, F14); S1-T4 als Wert vor Kappungen neu gefasst, Zusatzprüfwert S1-T4a durch WS-S |
| P18 | minor | 3.2, 3.12, D6 | 30 kWp als harte USt-Grenze | übernommen | D6 bleibt erfüllt (bis 30 kWp ohne Nachweis); größere Anlagen auf oder bei Wohngebäuden per Attribut; Prüfung am Gesetzestext in 10.2 |
| P19 | minor | 3.11 | variantenspezifische Vermieterkosten fehlen im Ertragswert-Reinertrag | übernommen | Reinertrag mit allen variantenspezifischen, nicht umlagefähigen Kosten; optionaler Abschlag (Stranded Asset) |
| P20 | minor | 3.2, 4.2, 4.5 | Kostenrisiko teils doppelt; Erklärung Basisfall/Median unvollständig | übernommen | Faktor auf Schätzung inkl. Risikozuschlag, Warnung bei Doppelung; schiefe Verteilungen als Hauptursache benannt |
| P21 | minor | 3.5, 3.7, 3.8, 6.2 | Regeln fehlen (§ 5a-Übergang, § 9 CO2KostAufG, Aufwendungsersatz, Sonderkündigung, § 559c, Mietrechtshistorie) | übernommen | in 3.5, 3.7, 3.8 ergänzt; Mietrechtshistorie als Pflichtdaten in 6.2 |
| P22 | minor | 3.8 | Energiepreisformel mischt netto/brutto und €/a mit ct/kWh | übernommen | Nettokomponenten × (1 + USt), Grundpreis getrennt, „Rest“ benannt |
| P23 | minor | 1.4 | keine Kennzahlen je WE | übernommen | Einheiten je WE und je m², Kennzahlentabelle im Fachmodus und Excel-Export |
| L1 | blocker | 2.5, 2.6, A2 | Endwertdifferenz bei unterschiedlichen Nachschüssen verzerrt | übernommen | Vergleichsregel ΔEW_A − ΔEW_B (F17), Nachschüsse kein Vergleichbarkeitsfehler, Orakel (g), Übernahme in den Vergleichsvertrag der Spezifikation |
| L2 | major | A3, 2.6, 4.2 | Horizont „ab Fertigstellung“ widerspricht festem T | übernommen | festes Kalenderdatum für alle Varianten und Läufe (2.8, A3, F16) |
| L3 | major | 1.4, 2.5 | Monatskennzahl undefiniert, Eigenanteil fehlt | übernommen | Definitionen nach Memo 07 §5.4, Kopfwert Jahr 1 und Ø 10 Jahre, Eigenanteil und Nachschüsse auf einen Blick |
| L4 | major | 1.4, 7.1, A4/B5 | Ampel ohne v1-Grundlage, Restwertregel und Tragbarkeit | übernommen | zusammen mit P11 umgesetzt |
| L5 | major | 2.5, D9 | Amortisation „mit Restwert“ nicht aussagekräftig | übernommen | zwei Begriffe, Restwertpfad RW_t je Methode, Haushaltsmodus zeigt die Vermögensamortisation |
| L6 | major | 5.3, 7.1 | Bedienweg für Haushalte in v1 unklar | übernommen | Betriebsmodell über Mittler, reduzierte Haushaltsvorlage, offene Frage A8 |
| L7 | major | 3.12, 0, D5 | Regime Kapitalgesellschaft ohne erweiterte Kürzung fehlt | übernommen | Zeile ergänzt, Relevanz differenziert, Steuerwarnhinweis für `wu_privat`, `tax_flat` als Abhilfe in A1 |
| L8 | major | 3.12, 7.1, 8.4, B4 | Abgeltungsteuer-Option doppelt abgewertet | teilweise | Pflichtumfang in WS-D, Pflichtsensitivität und Fehlerrichtung übernommen; Voreinstellung bleibt „aus“, weil v1 nach D5 vor Steuern rechnet |
| L9 | major | D5, 8.4, A1 | Schnittstellentests nur im optionalen WS-X | übernommen | Pflichttests mit Test-Steuermodul ab Phase 1 (WS-D); Begründung von D5 abgeschwächt |
| L10 | major | A7, 3.8, F5 | 2045-Annahme wirkt automatisch | übernommen | zusammen mit P9 umgesetzt |
| L11 | major | 2.6, A2 | Habenzins WU widersprüchlich, MC-Abstand inkonsistent | übernommen | zusammen mit P2 umgesetzt; MC-Abstand passend zum Startwert (F18) |
| L12 | major | 11.2, WS-L | weitere Widersprüche zwischen den Memos fehlen | übernommen | F19 (Preise, Nutzungsdauern, KG 700, Risikozuschlag), F20 (Prozesse), F21 (LHS); Werte in 3.8 als Beobachtung gekennzeichnet |
| L13 | major | 8.3, 8.2 | Abnahme von WS-D hängt an WS-F und WS-D2 | übernommen | WS-D mit Skelett-Instrumenten bzw. Mocks; vollständige Orakel-Suite als Abnahme der Integration |
| L14 | major | 6, 6.4, 8.5, 10.2 | Prüfrolle, Freigaberegel und Aufwand fehlen | übernommen | Abschnitt 6.5 mit Rollen, Freigaberegel und grober Aufwandsschätzung (Abl.); offene Frage B14 |
| L15 | minor | 3.5, C10 | Mieterstrom widersprüchlich eingeordnet | übernommen | v1 nur frei definierte Zahlungsreihe mit Warnung, Modul v2 |
| L16 | minor | 3.9, 5.6 | Belegungsbindung widersprüchlich eingeordnet | übernommen | Mietobergrenze in v1, Belegungsbindung mit Erlöswirkung in v2 |
| L17 | minor | 5.7, C4 | zwei Rechenzeitziele | übernommen | Abnahme nach 5.7, Zielwerte des Shiny-Viewers in C4 |
| L18 | minor | 7.1 | Gesellschafterebene widersprüchlich | übernommen | aus der Zeile genommen, Vermerk zu C11 |
| L19 | minor | 9 S2 | KfW-Darlehen lesen sich wie Investitionskosten | übernommen | Darlehensbeträge und Gesamtinvestition getrennt genannt |
| L20 | minor | 4.3 | Replikatgröße fest mit 1.000 Läufen angegeben | übernommen | „10 Replikate zu je N/10 Läufen“, F21 |
| L21 | minor | 2.5, 1.4 | Haushaltssicht ohne Kleinvermieter | übernommen | Haushaltssicht je Perspektive; Kleinvermieter mit monatlichem Cashflow inkl. Mieten und Umlage |
| L22 | minor | 3.9, 3.12 | § 35c-Bestätigung der ESt für Laien nicht beurteilbar | übernommen | Feld „voraussichtliche tarifliche ESt“ deckelt und warnt; Variantenpaar BEG gegen § 35c |
| L23 | minor | 6.2, 3.9 | Förderberechtigungs-Check fehlt | übernommen | Check der gewählten Programme in v1, Vorschlagsfunktion in v1.1 |
| L24 | minor | 3.12, 9 S3 | Warnhinweis zu Nebenerlösen befreiter Genossenschaften fehlt | übernommen | Warnhinweis mit Befreiungsgrenzen ergänzt (3.12, S3) |
| L25 | minor | 10.3, 2.5 | Behandlung der Restschulden am Horizont unklar | übernommen | nominaler Abzug, keine Vorfälligkeitsentschädigung (2.5, 10.3) |
