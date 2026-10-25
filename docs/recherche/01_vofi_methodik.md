# Recherche-Memo 01: VoFi-Methodik und Finanzmathematik (Rechenkern)

| | |
|---|---|
| **Projekt** | VoFi-Tool (R) für Neubau und energetische Sanierung, Wohnungswirtschaft und Privatpersonen |
| **Thema** | Methodik des Vollständigen Finanzplans (VoFi) nach Grob, Ausgleichsregeln, Kennzahlen, Alternativenvergleich, Periodisierung, Nominal-/Realrechnung, Testorakel |
| **Stand** | 25.10.2026 |
| **Status** | Recherche-/Entscheidungsgrundlage für Phase 2 (Konzept und technische Spezifikation) |
| **Ablage** | `docs/recherche/01_vofi_methodik.md` |

> **Lesehinweis.** In Abschnitt 0 stehen die Entscheidungsvorschläge. Die Abschnitte 1 bis 9 begründen sie und legen
> Formeln und Konventionen fest. Abschnitt 10 enthält die vollständig durchgerechneten Referenzbeispiele: Sie dienen
> als Testorakel für die R-Engine. Dort steht auch das Python-Skript, mit dem sie erzeugt wurden. Bezeichner und
> Schlüssel im Code sind englisch (snake_case), alle Texte für Nutzer sind deutsch. Zahlen sind im deutschen
> Format angegeben (Tausenderpunkt, Dezimalkomma). Gerundet wird nur für die Anzeige.

---

## 0. Kurzfassung und Entscheidungsvorschläge

**Kernaussage.** Der VoFi bildet alle Zahlungen einer Investition je Periode explizit ab: die originären Zahlungen
und die derivativen aus Finanzierung, Wiederanlage und Steuern. Zielgröße ist der Vermögensendwert am Planungshorizont.
Im Unterschied zu Kapitalwert und internem Zinsfuß braucht der VoFi keine impliziten Prämissen (einheitlicher
Kalkulationszins, Wiederanlage zum internen Zinsfuß). Soll- und Habenzinsen dürfen sich unterscheiden, Kreditverträge
werden realistisch abgebildet (Annuität, Ratentilgung, endfällig, tilgungsfreie Jahre, Tilgungszuschuss,
Bereitstellungsprovision), und Liquiditätsengpässe werden sichtbar. Damit eignet sich der VoFi als Rechenkern für
die Monte-Carlo-Simulation: Jeder Lauf ist ein vollständiger, nachvollziehbarer Finanzplan.

| Nr. | Entscheidungsvorschlag | Begründung (Kurz) |
|---|---|---|
| E1 | Der Rechenkern ist eine **periodenweise Vorwärtsrekursion**. Alle Zinsen der Periode t werden **nachschüssig auf die Bestände am Ende von t−1** berechnet. | Die Rechnung ist nicht zirkulär, braucht keine Gleichungssysteme, lässt sich über Simulationsläufe vektorisieren und entspricht dem Lehrbuchstandard (Grob). |
| E2 | Die Ausgleichsregeln haben eine **feste, konfigurierbare Rangfolge**. Überschuss: Kontokorrent tilgen → Mindestliquidität auffüllen → (optional) Sondertilgung → Geldanlage. Defizit: Guthaben über Mindestliquidität auflösen → Kontokorrent bis Limit → Liquiditätsreserve → Engpass-Policy (`equity_call`, `penalty_rate` oder `stop`). | Bei s > h maximiert diese Rangfolge den Endwert. Limitverletzungen werden nie still behandelt, sondern als Flag ausgewiesen (wichtig für die MC-Statistik). |
| E3 | **Primäre Zielgröße ist der VoFi-Endwert (EW)** und die **Endwertdifferenz ΔEW** gegenüber der Unterlassungsalternative mit identischen Eigenkapitalströmen. Die EK-Rentabilität ist sekundär. | ΔEW ist immer definiert, additiv interpretierbar und robust (auch bei EK = 0 und Verlusten). Renditen können undefiniert sein. |
| E4 | **Klassische VoFi-EK-Rentabilität** r_EK = (EW/EK_0)^(1/T) − 1 bei einer einzigen Einlage. Bei mehreren Einlagen oder Entnahmen gilt als **Standardverallgemeinerung die MIRR-Logik (R3)**: Entnahmen werden mit dem Habenzins aufgezinst, Einlagen mit dem Habenzins abgezinst. Der Equity-IRR (R2) wird nur ergänzend ausgewiesen. | R3 ist eindeutig, immer berechenbar, wenn Zähler und Nenner positiv sind, und **rangidentisch mit ΔEW** (Beweis in 4.3). R2 kann mehrdeutig sein und reagiert stark auf späte Nachschüsse (Beispiel (c2): 16,97 % gegenüber 10,89 %). |
| E5 | Für EK_0 = 0 oder EW ≤ 0 wird **r_EK = NA mit Begründungscode** ausgewiesen. Ersatzweise stehen ΔEW, das Entnahme-Äquivalent, die eigenfinanzierte VoFi-Gesamtkapitalrendite und der maximale Finanzierungsbedarf (max. KK, Summe Nachschüsse) zur Verfügung. | So entstehen keine Scheingenauigkeiten (unendliche oder komplexe Renditen). In der MC-Statistik wird der NA-Anteil getrennt ausgewiesen. |
| E6 | **Alternativen** werden als **vollständige Einzel-VoFis** mit gleichem EK-Budget, gleichen Einlagen und Entnahmen, gleichem Horizont und gleichen Konto-Konditionen gerechnet und über ΔEW verglichen. Ein „Differenz-VoFi“ dient nur der Erklärung (zeilenweise Differenz zweier VoFis). Ein VoFi auf Differenzzahlungen ist nur als ausdrücklich gekennzeichneter Vereinfachungsmodus zulässig. | Die Ausgleichsoperatoren sind nichtlinear (max/min, s ≠ h, Limits), daher gilt VoFi(A) − VoFi(B) ≠ VoFi(A − B). |
| E7 | Das **Periodenraster ist ein Vektor von Periodenlängen** (nicht äquidistant). Standard: Bauphase monatlich (alternativ quartalsweise), Betriebsphase jährlich. **Kreditmodule rechnen in ihrer Vertragsfrequenz** (z. B. monatliche KfW-Annuität) und werden auf das VoFi-Raster aggregiert. | Die Bauphase wird genau abgebildet (Teilvalutierung, Bauzeitzinsen, Bereitstellungsprovision), ohne die 30- bis 50-jährige Betriebsphase monatlich rechnen zu müssen. Weil Zinssätze ohnehin periodenspezifische Vektoren sind, kostet das im Kern kaum zusätzliche Komplexität. |
| E8 | **Der Kern rechnet nominal.** Reale Größen entstehen nur durch Deflationierung bei der Ausgabe (EW_real, r_real nach Fisher). Eingaben erfolgen in Preisen des Basisjahrs mit nominalen Steigerungsraten (oder real plus Inflation). | Kreditverträge sind nominal. Den Realwertverlust der Schulden erfasst nur die Nominalrechnung. Eine gemischte Real-/Nominalrechnung ist eine klassische Fehlerquelle. |
| E9 | **Kredite sind Zustandsautomaten** (Bestand, Rate, Restlaufzeit, Zinssatz), die in der Periodenschleife fortgeschrieben werden. Ein **Tilgungszuschuss** ist eine zahlungsunwirksame Bestandsminderung. Die Wirkung ist wählbar: `shorten_term` (Standard, entspricht der KfW-Formulierung „reduziert Ihr Darlehen und verkürzt die Laufzeit“) oder `reduce_installment`. | Sondertilgung, Anschlusszins (stochastisch in der MC), Tilgungszuschuss und Kontokorrent-Wechselwirkungen lassen sich so ohne Sonderfälle abbilden. Beispiel (b) zeigt, dass die Wahl ΔEW messbar verändert. |
| E10 | Die Engine wird **über Simulationsläufe vektorisiert**. Alle Zeitreihen sind Matrizen [n_sim × n_perioden], der deterministische Fall ist n_sim = 1. | Die MC-Laufzeit wird beherrschbar (Größenordnung Sekunden für 10.000 Läufe × 50 Perioden), und deterministische und stochastische Rechnung nutzen denselben Code. |
| E11 | Die **Steuerzeile ist ein Slot**: eine Hook-Funktion, die aus den vor dem Ausgleich bekannten Größen der Periode die Steuerzahlung bestimmt. In v1 ist sie 0, **auch in der Unterlassungsalternative**. | Der Slot bleibt nicht zirkulär. Später lässt sich ein Pauschalsteuermodus oder ein detailliertes Regime ergänzen, ohne den Kern zu ändern. Eine Steuer nur auf der Investitionsseite würde den Vergleich verzerren. |
| E12 | Der **Restwert ist eine eigene Zeile mit wählbarer Methode** (Marktwertfortschreibung, Ertragswert, bauteilbezogener Restwert, Vervielfältiger, null). Kennzahlen werden **mit und ohne Restwert** ausgewiesen. | Bei Immobilien ist der Restwert oft der größte Einzeltreiber, siehe Beispiel (c): Der Endwert ist nur über den Restwert positiv. |
| E13 | Die **Testorakel (a) bis (f) und die Invarianten I1 bis I6** (Abschnitt 3.5) werden als `testthat`-Tests übernommen. Toleranz: 1e-6 gegen die ungerundeten Skriptwerte, 0,005 gegen die gerundeten Tabellenwerte. | So lässt sich die R-Engine eindeutig und regressionssicher verifizieren. |

**Zur Ertragsteuer (Einschätzung aus Sicht der Methodik).** Methodisch lassen sich Steuern im VoFi problemlos
integrieren (Zeile „Steuern“, siehe 2.6). Die Komplexität liegt im Steuerrecht: Die Perspektiven sind sehr
verschieden (Privatperson mit Vermietung, Selbstnutzer, Kapitalgesellschaft mit erweiterter Gewerbesteuerkürzung,
Vermietungsgenossenschaft, kommunales Unternehmen), dazu kommen AfA-Regime, die Abgrenzung von
Erhaltungs- und Herstellungsaufwand und die Verlustverrechnung. **Empfehlung:** v1 rechnet vor Steuern mit
vorbereitetem Slot. Als v1.1 kommt optional ein *Pauschalsteuermodus* mit einem Satz auf (Überschuss − Zinsen − AfA +
Habenzinsen), sofortiger Verlustverrechnung und Anwendung in beiden Alternativen. Detailregime erst ab v2. Die
abschließende Bewertung gehört ins Steuer-Memo.

---

## 1. Einordnung und Grundprinzipien

### 1.1 Begriff

Der **Vollständige Finanzplan (VoFi)** geht auf Heinz Lothar Grob zurück (Grob 1989; Grob 2006, 5. Aufl.). Er ist
eine tabellarische, periodenbezogene Darstellung aller Zahlungen, die einer Investitionsentscheidung zuzurechnen sind:

1. **originäre Zahlungen** der Investition (Zahlungsfolge: Anschaffungs- und Herstellungsauszahlungen, laufende
   Ein- und Auszahlungen, Liquidationserlös oder Restwert),
2. **derivative Zahlungen** aus Finanzierung (Kreditaufnahme, Zinsen, Tilgung, Gebühren), Wiederanlage
   (Anlage, Auflösung, Habenzinsen), Steuern sowie Einlagen und Entnahmen der Eigentümer.

Jede Periode wird durch Ausgleichsregeln ausgeglichen, der **Finanzierungssaldo ist in jeder Periode 0**. Am Horizont
ergibt sich der **Vermögensendwert** als Saldo der Bestände (Guthaben minus Schulden). Er wird mit dem Endwert der
**Unterlassungsalternative** verglichen (Eigenkapital zum Habenzins angelegt).

### 1.2 Prinzipien, die die Implementierung leiten

| Prinzip | Bedeutung für die Engine |
|---|---|
| **Vollständigkeit** | Jede Zahlung, auch Zinseszins auf Zwischenguthaben, Bereitstellungsprovisionen und Zuschüsse, erscheint explizit. Es gibt keine „impliziten“ Ergänzungsinvestitionen. |
| **Explizitheit der Prämissen** | Soll- und Habenzinsen, Kreditkonditionen, Ausgleichsregeln, Restwertmethode und Horizont sind Parameter und erscheinen im Bericht. |
| **Endwertorientierung** | Das Ziel ist Vermögensstreben (Endwertmaximierung). Einkommensstreben (Entnahmemaximierung) wird über das Entnahme-Äquivalent abgebildet (4.6). |
| **Unterlassungsalternative** | Jede Entscheidung wird gegen die Alternative „Mittel zum Habenzins anlegen“ (bzw. gegen Ohnehin-/Bestandsvarianten) gemessen. |
| **Transparenz für Entscheider** | Die Tabelle ist das Ergebnis (prüfbar für Aufsichtsrat, Bank oder Förderstelle), keine Blackbox-Kennzahl. |

### 1.3 Literatur (Auswahl)

- Grob, H. L. (1989): *Investitionsrechnung mit vollständigen Finanzplänen*. München: Vahlen. (Grundlagenwerk.)
- Grob, H. L. (1993): *Capital Budgeting with Financial Plans*. Wiesbaden: Gabler. (Englische Fassung.)
- Grob, H. L. (2006): *Einführung in die Investitionsrechnung. Eine Fallstudiengeschichte*. 5., vollst. überarb. und erw.
  Aufl., München: Vahlen, ISBN 978-3-8006-3276-3 (Katalognachweis KIT, siehe Quellen). VoFi-Tabellen,
  VoFi-EK-Rentabilität, Unterlassungsalternative, Steuern im VoFi.
- Grob, H. L.; Mrzyk, A. P. (1997): *Risiko-Chancen-Analyse in der Investitionsrechnung – Integration von VOFI und
  Crystal Ball*. Universität Münster (elektronische Ausgabe; Katalognachweis miami.uni-muenster.de). Direktes Vorbild
  für die Kopplung VoFi und Monte-Carlo.
- Kruschwitz, L.; Lorenz, D. (2019): *Investitionsrechnung*. 15. Aufl., Berlin/Boston: De Gruyter Oldenbourg,
  ISBN 978-3-11-058735-7. (Vermögens- und Einkommensstreben, Kapitalwert und Endwert, vollkommener und
  unvollkommener Kapitalmarkt.) Neuere Auflagen sind möglich, das wurde nicht geprüft.
- Götze, U.: *Investitionsrechnung*. Berlin: Springer Gabler (Auflage nicht geprüft; behandelt VoFi, Endwert- und
  Sollzinssatzverfahren, Baldwin-Zins).
- Ropeter, S.-E. (1998): *Investitionsanalyse für Gewerbeimmobilien*. Köln: Rudolf Müller (Schriften zur
  Immobilienökonomie). VoFi-Anwendung im Immobilienkontext. Bibliografische Angaben nicht online verifiziert.

*Hinweis:* Die hier definierten Konventionen (Rangfolge, Zinszeitpunkt, Kennzahlvarianten) entsprechen dem
Lehrbuchstandard. Wo die Literatur Wahlmöglichkeiten lässt, ist eine Projektentscheidung mit Begründung
dokumentiert. Für die Testorakel gelten ausschließlich die in 10.1 genannten Konventionen.

---

## 2. Aufbau der VoFi-Tabelle

### 2.1 Zeitachse, Vorzeichen, Notation

```text
Zeitpunkte      t = 0, 1, …, T          (t = 0: Investitions- bzw. Baubeginn)
Periode t       = Intervall (t−1, t], Länge Δ_t in Jahren (Standard Δ_t = 1)
Zeit in Jahren  τ_t = Σ_{u≤t} Δ_u ;  Horizont in Jahren  T_J = τ_T
Vorzeichen      Zufluss (+), Abfluss (−) in Zahlungszeilen; Bestände ≥ 0
Zahlungszeitpunkt: alle Zahlungen einer Periode fallen am Periodenende t an (nachschüssig)
```

| Symbol | Bedeutung |
|---|---|
| z_t | Zahlungsfolge der Investition (originär) |
| ZU_t | zahlungswirksame Investitionszuschüsse |
| EL_t, EN_t | Einlagen und Entnahmen der Eigentümer (EK_0 = EL_0) |
| D_k,t | Nennbetrag der Auszahlung von Kredit k in t; κ_k = Auszahlungskurs |
| B_k,t | Kreditstand (Restschuld) von Kredit k am Ende von t |
| i_k,t | Periodenzinssatz von Kredit k in Periode t |
| Z_k,t, T_k,t, ST_k,t, P_k,t | Sollzinsen, planmäßige Tilgung, Sondertilgung, Provisionen und Gebühren |
| TZ_k,t | Tilgungszuschuss (zahlungsunwirksame Bestandsminderung) |
| KK_t, s_t | Kontokorrentstand, Periodensollzins Kontokorrent |
| G_t, h_t | Guthabenstand (Geldanlage), Periodenhabenzins |
| St_t | Steuerzahlung (Slot; v1 = 0) |
| BS_t | Bestandssaldo = G_t − KK_t − Σ_k B_k,t |
| EW | VoFi-Endwert = BS_T |

### 2.2 Zeilenstruktur (Zahlungsteil)

| Nr. | Block | Zeile (Anzeige) | Schlüssel (Vorschlag) | Vorzeichen | Bestimmung |
|---|---|---|---|---|---|
| 1 | Zahlungsfolge | Zahlungsfolge der Investition (ggf. aufgegliedert: Investitionsauszahlungen, Mieteinzahlungen, Bewirtschaftung, Energiekosten, Restwert …) | `cf_project` | ± | exogen (Cashflow-Module) |
| 2 | Zuschüsse | Investitionszuschüsse (zahlungswirksam) | `grant_cash` | + | exogen (Förderparameter inkl. Auszahlungszeitpunkt) |
| 3 | Eigenkapital | Einlage | `equity_in` | + | exogen; endogen bei Policy `equity_call` (Zeile „Nachschuss“) |
| 4 | Eigenkapital | Entnahme | `equity_out` | − | exogen (Ausschüttung, Konsum, Lebenshaltung) |
| 5 | Kredit k | Aufnahme (Auszahlungsbetrag κ_k·D_k,t) | `loan_<k>_draw` | + | exogen (Abrufplan) |
| 6 | Kredit k | Tilgung (planmäßig) | `loan_<k>_repay` | − | Kreditmodul |
| 7 | Kredit k | Sondertilgung | `loan_<k>_prepay` | − | Ausgleichsregel (optional) oder Plan |
| 8 | Kredit k | Sollzinsen | `loan_<k>_interest` | − | Kreditmodul: i_k,t·B_k,t−1 |
| 9 | Kredit k | Provisionen und Gebühren (Bereitstellungsprovision, Bearbeitungsentgelt) | `loan_<k>_fees` | − | Kreditmodul |
| 10 | Kontokorrent | Aufnahme | `od_draw` | + | Ausgleich |
| 11 | Kontokorrent | Tilgung | `od_repay` | − | Ausgleich |
| 12 | Kontokorrent | Sollzinsen | `od_interest` | − | s_t·KK_t−1 (vor Ausgleich bekannt) |
| 13 | Geldanlage | Anlage | `dep_invest` | − | Ausgleich |
| 14 | Geldanlage | Auflösung | `dep_withdraw` | + | Ausgleich |
| 15 | Geldanlage | Habenzinsen | `dep_interest` | + | h_t·G_t−1 (vor Ausgleich bekannt) |
| 16 | Steuern | Ertragsteuern (Slot) | `tax` | ∓ | v1: 0 |
| 17 | **Saldo** | **Finanzierungssaldo** | `balance_check` | | Summe 1 bis 16, muss 0 sein |

```text
Finanzierungssaldo_t = z_t + ZU_t + EL_t − EN_t
                     + Σ_k ( κ_k·D_k,t − T_k,t − ST_k,t − Z_k,t − P_k,t )
                     + KA_t − KT_t − s_t·KK_{t−1}
                     − GA_t + GL_t + h_t·G_{t−1}
                     − St_t                                    ≡ 0
```

### 2.3 Bestandsgrößen

| Zeile (Anzeige) | Fortschreibung |
|---|---|
| Kreditstand k | B_k,t = B_k,t−1 + D_k,t − T_k,t − ST_k,t − TZ_k,t |
| Tilgungszuschuss k (zahlungsunwirksam, Merkzeile) | TZ_k,t |
| Kontokorrentstand | KK_t = KK_t−1 + KA_t − KT_t |
| Guthabenstand | G_t = G_t−1 + GA_t − GL_t |
| **Bestandssaldo** | BS_t = G_t − KK_t − Σ_k B_k,t |
| *optional:* Marktwert der Immobilie | V_t (Wertpfad, nicht zahlungswirksam) |
| *optional:* Nettovermögen | NV_t = BS_t + V_t·(1 − Verkaufskosten) |

Für die Anzeige stehen Perioden als Spalten (Grob-Layout). Bei Horizonten über 15 Perioden wird eine transponierte
Ansicht angeboten (Perioden als Zeilen). Beide Ansichten werden aus demselben Long-Format erzeugt
(`row_key × period × value`).

### 2.4 Kreditbausteine (Finanzmathematik)

Alle Formeln gelten je Kredit k. Der Index k wird weggelassen. Periodenzins i = Sollzins je Zahlungsperiode.

**Phasen.** t_A = letzte Auszahlungsperiode. Die erste Leistungsperiode ist t_A + 1. Tilgungsfreie Perioden g
(Anlaufjahre) folgen ab t_A + 1. Die Tilgung beginnt in t_A + g + 1. Die Laufzeit n zählt ab t_A + 1 inklusive der
tilgungsfreien Perioden, die Fälligkeit ist also t_A + n. In der Bauphase (t ≤ t_A) fallen Zinsen auf den bereits
ausgezahlten Bestand (Bauzeitzinsen) und Bereitstellungsprovision auf den nicht abgerufenen Betrag an.

**(1) Annuitätendarlehen, Annuität aus der Laufzeit**

```text
Tilgungsfreie Perioden:     Z_t = i·B_{t−1},  T_t = 0
Annuität (ab Tilgungsbeginn, Basis B_g = Bestand bei Tilgungsbeginn):
    A = B_g · i / (1 − (1+i)^−(n−g))          (i ≠ 0;  i = 0: A = B_g/(n−g))
Z_t = i·B_{t−1};   T_t = min(A − Z_t, B_{t−1});   in der Fälligkeitsperiode T_t = B_{t−1}
Restschuld nach m Tilgungsperioden:  B = B_g·(1+i)^m − A·((1+i)^m − 1)/i
```

**(2) Annuitätendarlehen mit anfänglichem Tilgungssatz τ** (in Deutschland üblich)

```text
A = D · (i + τ)        (D = Nennbetrag)
rechnerische Volltilgungsdauer  n* = ln((i+τ)/τ) / ln(1+i)
    Beispiel: i = 3,8 %, τ = 2 %  →  n* = ln(2,9)/ln(1,038) = 28,55 Jahre
Am Ende der Zinsbindung: Restschuld wird mit Anschlusszins i' weitergeführt (siehe (7)).
```

**(3) Ratentilgung (Abzahlungsdarlehen)**

```text
R = B_g / (n − g);   T_t = min(R, B_{t−1});   Z_t = i·B_{t−1}   (Kapitaldienst fällt linear)
```

**(4) Endfälliges Darlehen (Festdarlehen)**

```text
Z_t = i·B_{t−1} = i·D;   T_t = 0 für t < t_A + n;   T_{t_A+n} = D
```

**(5) Unterjährige Zahlweise (m Zahlungen je Jahr, Sollzins p. a. nominal i_nom)**

```text
Periodenzins i_m = i_nom / m;  effektiver Jahreszins i_eff = (1 + i_nom/m)^m − 1
(Der Effektivzins nach PAngV enthält zusätzlich Kosten wie Disagio und Entgelte; im VoFi
 sind diese ohnehin explizit erfasst.)
Aggregation auf eine VoFi-Periode: Σ Zinsen und Σ Tilgungen der m Teilzahlungen; Bestand am Periodenende exakt.
```

**(6) Auszahlung, Disagio, Teilvalutierung, Bereitstellungsprovision**

```text
Auszahlungsbetrag = κ·D_t (κ < 1: Disagio);  Zinsen und Tilgung auf den Nennbetrag
Bereitstellungsprovision P_t = p · (D_zugesagt − Σ_{u<t} D_u)   für Perioden t ≥ t_frei
    KfW-Wohngebäudekredit 261: „Ab dem 13. Monat berechnen wir eine Bereitstellungsprovision …
    0,15 % pro Monat für noch nicht abgerufene Kreditbeträge“; Abruffrist 12 Monate, verlängerbar bis 36 Monate
    (KfW-Programmseite 261, abgerufen 25.10.2026). Parameter gehören in die YAML-Bibliothek, nicht in den Code.
```

**(7) Zinsbindung und Anschlussfinanzierung.** Nach Ablauf der Zinsbindung (Periode t_ZB) gilt der Anschlusszins i'
(Szenario oder stochastischer Pfad in der MC). Varianten (Parameter `refi_rule`):

| Regel | Neue Rate | Einsatz |
|---|---|---|
| `keep_term` | A' = B·i'/(1 − (1+i')^−n_rest) | Darlehen mit fester Gesamtlaufzeit |
| `keep_tilg_rate` | A' = B·(i' + τ') mit τ' = τ (oder Parameter) | anfänglicher Tilgungssatz (Standard bei Bankdarlehen) |
| `keep_payment` | A' = A; Laufzeit ergibt sich | Warnung, wenn A' ≤ i'·B (negative Tilgung) |

Das Kündigungsrecht nach § 489 Abs. 1 Nr. 2 BGB (zehn Jahre nach vollständigem Empfang, Frist sechs Monate) und
Vorfälligkeitsentschädigungen werden in v1 nicht modelliert. Sie sind als Grenze dokumentiert.

**(8) Tilgungszuschuss (KfW-Logik).** Der Zuschuss wird nach Abschluss des Vorhabens dem Kreditkonto gutgeschrieben.
Die KfW formuliert für den Kredit 261: „Den Tilgungszuschuss schreiben wir Ihnen nach Abschluss Ihres Vorhabens gut“,
er „reduziert Ihr Darlehen und verkürzt die Laufzeit“, eine Barauszahlung ist nicht möglich (KfW-Programmseite 261,
abgerufen 25.10.2026). Abbildung im VoFi:

```text
In Periode t_TZ (nach der planmäßigen Leistung):  B_t ← B_t − min(TZ, B_t)     (zahlungsunwirksam)
Variante shorten_term (Standard):     Rate (A bzw. R) bleibt auf Basis des ursprünglichen Nennbetrags;
                                      der Kredit ist früher getilgt.
Variante reduce_installment:          Neuberechnung von A bzw. R auf die Restschuld über die Restlaufzeit
                                      (liegt t_TZ in der tilgungsfreien Zeit: Berechnung bei Tilgungsbeginn).
```

Wirkung auf das Vermögen: BS steigt in t_TZ um TZ (siehe Invariante I2). Folgen für Steuern und Miete
(Kürzung von Herstellungskosten bzw. umlagefähigen Kosten, § 559a BGB „Drittmittel“) werden über die
Cashflow-Module und den Steuer-Slot berücksichtigt, nicht im Kreditmodul.

**(9) Sondertilgung.** Entweder **geplant** (exogene Beträge) oder **regelbasiert** aus Überschüssen
(Ausgleichsschritt Ü3, siehe 3.2). Danach bleibt die Rate standardmäßig gleich und die Laufzeit verkürzt sich.
Vertragliche Obergrenzen (z. B. x % des Nennbetrags p. a.) sind Parameter.

**(10) Rundung.** Gerechnet wird ohne Rundung. Optional (`round_payments = TRUE`) werden vertragliche Raten auf
Cent gerundet, wie in der Bankpraxis. Die Testorakel rechnen ungerundet.

### 2.5 Zuschüsse, Einlagen, Entnahmen, EK-Budget

- **Investitionszuschüsse** (z. B. Zuschüsse der Bundesförderung) sind eine eigene Zeile mit **Auszahlungszeitpunkt**.
  Meist fließen sie erst nach Abschluss und Nachweis. In der Bauphase entsteht deshalb eine
  Zwischenfinanzierung, die der VoFi automatisch über KK oder Guthaben abbildet.
- **Zinsverbilligung** ist kein eigener Posten. Sie steckt im Zinssatz des Förderkredits und zeigt sich im
  Vergleich mit einem Marktkredit.
- **EK-Budget:** EK_0 ist das *verfügbare* Eigenkapital, nicht das benötigte. Übersteigt das Budget den Bedarf, fließt
  der Überschuss in t = 0 in die Geldanlage. In allen Alternativen wird dasselbe Budget angesetzt (Vergleichbarkeit,
  siehe 5.1).
- **Einlagen und Entnahmen:** Für Unternehmen Kapitalzuführung bzw. Ausschüttung. Für Privatpersonen laufende
  Sparraten aus dem Haushaltseinkommen (Einlagen) bzw. Konsum (Entnahmen). In der Policy `equity_call` werden
  Defizite über dem KK-Limit als **endogene Nachschüsse** gebucht und gesondert ausgewiesen.

### 2.6 Steuer-Slot

```text
St_t = f_tax( Bemessungsgrundlage_t , Zustand_t )
Bemessungsgrundlage_t aus vor dem Ausgleich bekannten Größen der Periode t, z. B.:
   steuerpflichtige Einzahlungen − abzugsfähige Auszahlungen − Σ Z_k,t − Σ P_k,t − AfA_t − s_t·KK_{t−1} + h_t·G_{t−1}
Zustand_t: Verlustvortrag, AfA-Restbuchwert u. a.
Zahlung in t (vereinfacht) oder in t+1 (Veranlagungs-Lag). Beides ist nicht zirkulär.
```

Der Slot muss **auch in der Unterlassungsalternative** wirken (Habenzinsen sind z. B. bei Privatpersonen
steuerpflichtig). Sonst würde die Investition systematisch bevorzugt.

---

## 3. Ausgleichsregeln, Zinskonventionen, Nicht-Zirkularität

### 3.1 Zinskonventionen (Projektstandard)

1. **Nachschüssig auf den Vorperiodenbestand:** Zinsen der Periode t = Zinssatz × Bestand am Ende von t−1 (nach
   Ausgleich, Sondertilgung und Tilgungszuschuss in t−1). Sie werden in t gezahlt bzw. gutgeschrieben.
2. **Sollzinsen werden nicht kapitalisiert**, sondern gezahlt (Zeile „Sollzinsen“). Reicht die Liquidität nicht,
   finanziert der Ausgleich sie über das Kontokorrent. Das ist ökonomisch gleichwertig zur Kapitalisierung zum
   KK-Zins, aber transparent.
3. **Habenzinsen werden gezahlt** (Zeile „Habenzinsen“) und über den Ausgleich wieder angelegt (Zinseszins).
4. **Periodenzinssätze** werden aus Jahreszinssätzen abgeleitet (Parameter je Instrument):
   - Kredite (vertraglicher Sollzins p. a. nominal): i_t = i_nom · Δ_t (bzw. i_nom/m bei Vertragsfrequenz m)
   - Geldanlage und Kontokorrent (effektiv p. a.): h_t = (1 + h_eff)^Δ_t − 1, s_t = (1 + s_eff)^Δ_t − 1
5. **In t = 0 fallen keine Zinsen an.** Zahlungen in t = 0 werden in t = 0 ausgeglichen.
6. **Konsistenzbedingung:** s_t ≥ h_t. Bei h_t > s_t gibt die Engine eine Warnung aus (Arbitrage, die die
   Rangfolge nicht ausnutzt). Negative Habenzinsen (Verwahrentgelte) sind zulässig.

### 3.2 Ausgleichsregeln und Rangfolge

S_t bezeichnet den **vorläufigen Saldo** der Periode t vor dem Ausgleich: alle Zeilen 1 bis 9, 12, 15 und 16.

**Überschuss (S_t ≥ 0):**

| Rang | Schritt | Betrag | Begründung |
|---|---|---|---|
| Ü1 | Kontokorrent tilgen | KT_t = min(S_t, KK_t−1) | teuerste Mittel zuerst zurückführen (s > h) |
| Ü2 | Mindestliquidität auffüllen | bis G = L_min,t | Reserve wiederherstellen (nur bei L_min > 0) |
| Ü3 | *optional:* Sondertilgung | Kredite absteigend nach i_k,t, nur wenn i_k,t > h_t; Obergrenzen; ggf. Anteil q des Rests | höher verzinste Schuld abbauen statt niedrig verzinst anlegen |
| Ü4 | Geldanlage | GA_t = Rest | Wiederanlage zum Habenzins |

**Defizit (S_t < 0), Bedarf N = −S_t:**

| Rang | Schritt | Betrag | Begründung |
|---|---|---|---|
| D1 | Guthaben oberhalb L_min auflösen | GL_t = min(N, max(G_t−1 − L_min, 0)) | billigste Quelle (Opportunitätskosten h) |
| D2 | Kontokorrent aufnehmen bis Limit | KA_t = min(N_rest, KL_t − KK_t−1) | Kosten s |
| D3 | Liquiditätsreserve angreifen | min(N_rest, G) | Flag „Reserve unterschritten“ |
| D4 | Engpass-Policy | `equity_call`: Nachschuss = N_rest (endogene Einlage) · `penalty_rate`: zweite KK-Tranche zum Überziehungszins s_t + Δs · `stop`: Abbruch bzw. NA in der MC | Flag „Limitverletzung“ mit Betrag und Periode |

**Eigenschaften.** Bei L_min = 0 gilt die Komplementarität G_t·KK_t = 0 (nie gleichzeitig Guthaben und KK). Wegen
s ≥ h maximiert die Rangfolge Ü1/D1 den Endwert für eine gegebene Zahlungsfolge (myopisch und zugleich global
optimal, weil die Bestände linear verzinst werden und jede Umschichtung zwischen G und KK sofort möglich ist).
**Ü3 ist eine Heuristik:** Sondertilgung lohnt nur, wenn die Mittel später nicht wieder über KK zu s > i_k beschafft
werden müssen. Eine kurzsichtige Regel kann das nicht erkennen. In Beispiel (a3) erhöht die Regel den EW um 635,34, in
anderen Konstellationen kann sie ihn senken. Deshalb gilt in v1: Ü3 ist standardmäßig aus. Bei Aktivierung gibt es einen Puffer (Sondertilgung nur aus Mitteln
oberhalb L_min + Puffer) und einen Warnhinweis.

**Voreinstellungen je Perspektive** (Parameter-Presets):

| Perspektive | KK-Interpretation | Limit | Policy D4 |
|---|---|---|---|
| Wohnungsunternehmen | Betriebsmittellinie bzw. Cash-Pool zum internen Verrechnungszins | unbegrenzt (Flag ab Schwelle) | `penalty_rate` |
| Privatperson (Vermieter oder Selbstnutzer) | Dispositionskredit bzw. Zwischenfinanzierung | gering (Parameter) | `equity_call` (Nachschuss aus Haushaltseinkommen). Flag, wenn Nachschuss > Sparfähigkeit |

### 3.3 Algorithmus je Periode (sprachneutraler Pseudocode)

```text
für t = 0 … T:
  1  F  ← z_t + ZU_t + EL_t − EN_t − St_t                    # exogen bzw. Slot (St_t aus Schritt 5)
  2  für jeden Kredit k:                                       # Zustandsautomat
        Z  ← i_k,t · B_k,t−1   (t > 0)
        P  ← Bereitstellungsprovision / Gebühren
        T  ← planmäßige Tilgung nach Typ und Phase
        B_k ← B_k,t−1 − T + D_k,t
        F  ← F + κ_k·D_k,t − Z − P − T
        falls t = t_TZ:  B_k ← B_k − min(TZ, B_k);  ggf. Rate neu berechnen
  3  HZ ← h_t · G_t−1 ;  KZ ← s_t · KK_t−1                    # t > 0
  4  S  ← F + HZ − KZ                                          # vorläufiger Saldo
  5  (Steuer-Slot: St_t aus Größen der Schritte 1–3; in Schritt 1 einsetzen; keine Rückkopplung)
  6  Ausgleich nach 3.2 → KT, KA, GA, GL, ST_k, Nachschuss, Flags
  7  G_t ← G_t−1 + GA − GL ;  KK_t ← KK_t−1 + KA − KT ;  B_k,t ← B_k − ST_k
  8  BS_t ← G_t − KK_t − Σ B_k,t ;  Kontrolle Finanzierungssaldo = 0
```

**Vektorisierung:** Alle Schritte sind elementweise (min/max/pmin/pmax über Vektoren der Länge n_sim). Die einzige
Schleife läuft über die Perioden (in der Praxis höchstens ca. 100 Perioden). Ein Lauf mit 10.000 Simulationen und
50 Perioden braucht damit rund 50 × 30 Vektoroperationen der Länge 10.000, also Sekundenbruchteile bis wenige
Sekunden in R.

### 3.4 Warum die Rechnung nicht zirkulär ist

- Zinsen der Periode t hängen nur von Beständen aus t−1 ab. Der vorläufige Saldo S_t ist vor dem Ausgleich
  vollständig bekannt.
- Der Ausgleich verändert nur Bestände am Ende von t. Diese beeinflussen erst die Zinsen in t+1.
- Steuern werden aus Größen berechnet, die vor dem Ausgleich bekannt sind (Habenzinsen und Sollzinsen von t eingeschlossen).
- Sondertilgungen verwenden nur den Überschuss von t.

*Abgrenzung:* Zinsen auf den Durchschnitts- oder Endbestand derselben Periode wären zirkulär (der Zins hängt vom
Bestand ab, der Bestand vom Zins). Für ein einzelnes Konto ist das geschlossen lösbar, mit dem Wechsel zwischen
Guthaben und KK aber nur noch stückweise. **Unterjährige Zahlungszeitpunkte** werden daher nicht durch
Mittelwert-Konventionen genähert, sondern bei Bedarf über ein feineres Raster abgebildet (Abschnitt 7).

### 3.5 Invarianten (für automatisierte Tests)

| Nr. | Invariante |
|---|---|
| I1 | Finanzierungssaldo_t = 0 für alle t (Toleranz 1e-8 × Volumen). |
| I2 | **Vermögensfortschreibung:** BS_t − BS_t−1 = z_t + ZU_t + EL_t − EN_t − St_t − Σ Z_k,t − Σ P_k,t − Σ (1−κ_k)·D_k,t + h_t·G_t−1 − s_t·KK_t−1 + Σ TZ_k,t. Tilgungen, Aufnahmen, Anlagen und Auflösungen sind vermögensneutral. |
| I3 | G_t ≥ 0, KK_t ≥ 0, B_k,t ≥ 0. Bei L_min = 0: G_t·KK_t = 0. KK_t ≤ KL_t, sofern keine Limitverletzung geflaggt ist. |
| I4 | **Vollkommener Kapitalmarkt:** Sind alle Zinssätze gleich i (Kredite, KK, Anlage) und gibt es keine Gebühren und kein Disagio, gilt ΔEW = (1+i)^T · [KW_i(z) + KW_i(ZU) + KW_i(TZ)]. Testfälle: Beispiel (d) und (b2). |
| I5 | EW ist streng monoton fallend in einer konstanten Zusatzentnahme E (Steigung ≤ −1 je Periode). Damit ist das Entnahme-Äquivalent eindeutig. |
| I6 | Unterlassungsalternative ohne Entnahmen und ohne KK: EW_U = Σ_t EL_t · Π_{u>t}(1+h_u). |

---

## 4. Kennzahlen

### 4.1 VoFi-Endwert (Vermögensendwert)

```text
EW = BS_T = G_T − KK_T − Σ_k B_k,T          (Restschulden am Horizont werden abgezogen)
EW (ohne Restwert) = EW − RW_T               (RW_T = in z_T enthaltener Restwert bzw. Liquidationserlös)
```

### 4.2 Unterlassungsalternative, Opportunitätsendwert, Endwertdifferenz

Die **Unterlassungsalternative U** ist ein VoFi ohne Investition und ohne Kredite, aber mit **denselben Einlagen
(inkl. endogener Nachschüsse) und Entnahmen** sowie denselben Konto-Konditionen (h, s, Limit). Ihr Endwert EW_U ist
der **Opportunitätsendwert**. Bei nur einer Einlage EK_0 gilt EW_U = EK_0·Π(1+h_t).

```text
ΔEW = EW − EW_U        Entscheidungsregel: Investition vorteilhaft ⇔ ΔEW > 0
```

*Hinweis zur Wahl von h:* h ist der **Wiederanlagezins** der tatsächlich nächstbesten Mittelverwendung. Für
Privatpersonen ist das z. B. Tages- oder Festgeld (ab v1.1 nach Steuern). Für Wohnungsunternehmen mit
Bestandsverschuldung ist es oft die vermiedene Fremdfinanzierung bzw. eine mögliche Sondertilgung von
Bestandsdarlehen, also eher der marginale Fremdkapitalzins. h ist ein **zentraler Sensitivitätsparameter** und
gehört in die Szenario- und MC-Definition.

### 4.3 VoFi-Eigenkapitalrentabilität

**R1, klassisch (eine Einlage EK_0 > 0 in t = 0, keine weiteren Einlagen oder Entnahmen):**

```text
r_EK = (EW / EK_0)^(1/T_J) − 1                    (T_J = Horizont in Jahren)
```

**R2, Equity-IRR:** interner Zinsfuß der Eigenkapitalströme aus Eigentümersicht

```text
0 = Σ_t (−EL_t + EN_t)·(1+r)^(−τ_t) + EW·(1+r)^(−τ_T)
```

Eindeutig nur bei einem Vorzeichenwechsel. Implizit werden spätere Einlagen mit r selbst diskontiert. Späte
Nachschüsse wirken dadurch „billig“, und R2 überzeichnet (Beispiel (c2): R2 = 16,97 %, R3 = 10,89 %).

**R3, modifizierte VoFi-EK-Rendite (MIRR- bzw. Baldwin-Logik), Projektstandard:**

```text
Akkumulationsfaktor  q_t = Π_{u=1..t} (1 + h_u)           (q_0 = 1)
Zähler   = EW + Σ_t EN_t · q_T/q_t                          (Entnahmen mit h auf T aufgezinst)
Nenner   = Σ_t EL_t / q_t                                   (Einlagen mit h auf t = 0 abgezinst)
r_EK,mod = (Zähler / Nenner)^(1/T_J) − 1                    (definiert, wenn Zähler > 0 und Nenner > 0)
```

*Eigenschaften:* R3 = R1, wenn nur EK_0 vorliegt. **Rangidentität mit ΔEW:** Für die Unterlassungsalternative ohne
KK gilt EW_U + Σ EN_t·q_T/q_t = Σ EL_t·q_T/q_t, also (1 + r_U)^T_J = q_T bzw. r_U = h (bei konstantem h). Da Nenner
und Entnahmeterm für Investition und Unterlassung identisch sind, gilt **r_EK,mod > r_U ⇔ EW > EW_U ⇔ ΔEW > 0**.
Braucht U selbst KK, bleibt die Rangidentität erhalten, nur ist r_U < h. R3 (und R1 als Spezialfall) steht damit nie im
Widerspruch zur Endwertregel. Für R2 gilt das nicht.

**Sonderfälle (Ausweis mit Begründungscode):**

| Fall | r_EK | Ausweis bzw. Ersatzgrößen |
|---|---|---|
| EK_0 = 0 und keine Einlagen (Nenner = 0) | NA (`no_equity`) | ΔEW, Entnahme-Äquivalent, max. KK-Stand (= impliziter EK-Bedarf), VoFi-Gesamtkapitalrendite (4.4); Variante mit Policy `equity_call` rechnen, dann ist R3 definiert (Beispiel (c2)) |
| EW ≤ 0 (bzw. Zähler ≤ 0) | NA (`equity_lost`) | „Eigenkapital vollständig verzehrt“; EW, ΔEW. Für Histogramme optional zensiert bei −100 % (deutlich gekennzeichnet) |
| negative Zwischen-Bestandssalden | unkritisch | BS_t < 0 ist bei Fremdfinanzierung normal. Kennzahlen hängen nur vom Horizont ab; Zwischenrisiken erfassen min. Nettoliquidität, DSCR und LTV |
| R2 mit mehreren Vorzeichenwechseln | NA (`irr_ambiguous`) | R3 verwenden |

### 4.4 VoFi-Gesamtkapitalrendite (eigenfinanziert) und Leverage

Die finanzierungsneutrale Projektsicht im VoFi: Alle Investitionsauszahlungen werden zu ihrem Zeitpunkt als
Einlagen gebucht, es gibt keine Kredite. Spätere Defizite und Überschüsse laufen über KK bzw. Anlage.

```text
r_GK = R3 dieses VoFi   (bei einer Investitionsauszahlung I_0:  r_GK = (EW_GK / I_0)^(1/T_J) − 1)
Leverage-Effekt = r_EK,mod − r_GK
```

Beispiele: (a) r_GK = 5,02 %, r_EK = 5,12 % (leicht positiver Leverage). (c) r_GK = 4,76 %, bei 100 % FK
ist r_EK nicht definiert.

### 4.5 Dynamische Amortisationsdauer im VoFi

```text
t_A = min { t : BS_u ≥ BS^U_u für alle u ≥ t }     (BS^U = Bestandssaldo der Unterlassungsalternative)
Variante „ohne Restwert“:  BS_T wird um RW_T gemindert (bzw. Restwertzeile = 0)
Variante „Vermögensamortisation“:  BS_t + RW_t(hypothetisch) ≥ BS^U_t  (RW_t = Liquidationswert bei Verkauf in t)
```

Die Forderung „für alle u ≥ t“ (dauerhaft) verhindert Scheinamortisation bei späteren Ersatzinvestitionen. Bei
Immobilien ist die Variante „ohne Restwert“ oft „keine Amortisation im Horizont“. Aussagekräftig ist dann die
Vermögensamortisation mit Marktwertpfad.

### 4.6 Entnahme-Äquivalent (VoFi-Annuität, Einkommensstreben)

```text
E* = konstante Zusatzentnahme je Jahr (t = 1…T), so dass  EW(E*) = EW_U (ohne Zusatzentnahme)
```

Interpretation: der Betrag, den der Investor jährlich **zusätzlich konsumieren bzw. ausschütten** kann und trotzdem
am Horizont so vermögend ist wie in der Unterlassungsalternative. E* ist wegen I5 eindeutig und wird per Bisektion
bzw. `uniroot` gelöst (vektorisiert: etwa 40 Engine-Läufe je Simulationsblock). Die Näherung
E ≈ ΔEW·h/((1+h)^T − 1) gilt nur, wenn die Zusatzentnahmen ausschließlich das Guthaben mindern. Sobald sie KK
auslösen, überschätzt die Näherung, z. B. in Beispiel (a): exakt 672,44, Näherung 701,89.
Ergänzend: **E_max** mit EW(E_max) = 0 (maximaler Konsum bei vollständigem Kapitalverzehr).

### 4.7 Klassische Verfahren und warum der VoFi vorzuziehen ist

```text
Kapitalwert            KW_i = Σ_t z_t·(1+i)^(−τ_t)
Interner Zinsfuß       IZF: KW_IZF = 0
Annuität               AN_i = KW_i · i/(1 − (1+i)^(−T))
Äquivalenz (vollkommener Kapitalmarkt, Soll = Haben = i):  ΔEW = KW_i·(1+i)^T      (Invariante I4)
```

| Kriterium | Kapitalwert | Interner Zinsfuß | VoFi |
|---|---|---|---|
| Kapitalmarktannahme | ein Zins für Anlage und Kredit | Wiederanlage implizit zum IZF | Soll ≠ Haben, mehrere Kredite, Limits |
| Finanzierungsstruktur | ignoriert (bzw. über Mischzins) | ignoriert | explizit (Kreditverträge, Förderkredite, Tilgungszuschuss) |
| Förderung auf Finanzierungsseite | nur bei manueller Umrechnung | nur bei manueller Umrechnung | automatisch. Beispiel (b): KW_2%(z) = −13.524,20 und IZF = 0,95 % verwerfen die Maßnahme, obwohl ΔEW = +9.482,79 (b1) bzw. +10.403,66 (b2), weil Tilgungszuschuss und Förderkredit auf der Finanzierungsseite wirken |
| Liquidität | nicht sichtbar | nicht sichtbar | KK-Bedarf, Nachschüsse und Flags je Periode |
| Eindeutigkeit | ja | nein bei mehreren Vorzeichenwechseln (Ersatzinvestitionen, Restwert) | ja (EW, ΔEW, R3) |
| Steuern | über Steuerparadoxon und Anpassung des Kalkulationszinses | schwierig | Zeile im Plan |
| Kommunikation | abstrakte Zahl | Prozentwert, oft falsch interpretiert | Tabelle wie Kontoauszug bzw. Finanzplan |

Kapitalwert und IZF der Zahlungsfolge werden **ergänzend** ausgewiesen (Anschlussfähigkeit an die Praxis),
gekennzeichnet als „finanzierungsneutral, vereinfachte Annahmen“.

### 4.8 Kennzahlen im Monte-Carlo-Kontext

| Zielgröße | Empfehlung |
|---|---|
| EW, ΔEW | **primär.** Verteilung, Erwartungswert, Quantile, P(ΔEW < 0), Expected Shortfall (z. B. 5 %) |
| r_EK,mod | sekundär. Quantile nur über definierte Läufe, **NA-Anteil getrennt ausweisen** |
| Entnahme-Äquivalent | optional (Rechenaufwand: Wurzelsuche je Lauf, vektorisiert machbar) |
| min. DSCR, max. LTV, max. KK, Summe Nachschüsse | Risiko- und Covenant-Sicht: P(DSCR_min < Schwelle), P(Limitverletzung) |
| Kritische Werte | deterministisch (Wurzelsuche) und als Tornado- bzw. Sensitivitätsdiagramm ergänzend zur MC |

---

## 5. Vergleich von Alternativen

### 5.1 Grundsätze der Vergleichbarkeit

1. **Gleiches EK-Budget** (gleiche Einlagen) in allen Alternativen. Nicht benötigtes EK wird angelegt.
2. **Gleiche Entnahmen** (bzw. gleiche Konsumansprüche bei Privatpersonen).
3. **Gleicher Horizont T** und gleiche Restwertmethode.
4. **Gleiche Konto-Konditionen** (h, s, Limits, Policies).
5. Unterschiede in Kapitalbindung und zeitlichem Profil gleicht der VoFi **automatisch** über Geldanlage bzw. KK aus.
   Das ersetzt explizite „Ergänzungsinvestitionen“ mit angenommener Rendite (ein methodischer Vorteil gegenüber
   Kapitalwertvergleichen mit unterschiedlichem Kapitaleinsatz).

### 5.2 Total-VoFi gegen Differenz-VoFi

- **Empfehlung:** Für jede Alternative wird ein vollständiger VoFi gerechnet, dann ΔEW_{A,B} = EW_A − EW_B. Zur
  Erklärung dient eine **Differenztabelle** (zeilenweise Differenz beider VoFis).
- Ein **VoFi auf Differenzzahlungen** (z_A − z_B mit eigener Finanzierung) stimmt nur bei linearem Ausgleich
  (s = h, keine Limits, keine regelbasierte Sondertilgung) mit der Totalrechnung überein. Zulässig ist er nur als
  gekennzeichneter **Inkrement-Modus**, z. B. wenn ein Unternehmen nur Mehrkosten und Mehrerträge einer Maßnahme kennt
  und die Liquidität auf Unternehmensebene gesteuert wird (KK unbegrenzt zum internen Zins). Diese Prämisse
  muss im Bericht stehen.

### 5.3 Energetische Sanierung: Alternativenset und Ohnehin-Kosten

| Alternative | Inhalt | typische Zahlungen |
|---|---|---|
| A0 Nichtstun / Weiterbetrieb | nur laufende Instandhaltung | steigende Energie- und CO2-Kosten (Vermieteranteil nach CO2-Kostenaufteilung), Leerstands- und Mietausfallrisiko, **erzwungene Maßnahmen** (z. B. ordnungsrechtliche Austauschpflichten, Ausfall der Heizung) zum Zeitpunkt t_k |
| A1 Ohnehin-Sanierung (Instandsetzung) | Erneuerung fälliger Bauteile ohne energetische Verbesserung | „Sowieso-Kosten“ zum Fälligkeitszeitpunkt, keine Energieeinsparung |
| A2 Energetische Sanierung (Standard X) | Ohnehin-Anteil + energiebedingte Mehrkosten | Vollkosten, Förderung (Zuschuss, Förderkredit, Tilgungszuschuss), Mehrmiete bzw. Energieeinsparung, verminderte CO2-Kosten, veränderter Restwert |
| A2' Zeitpunktvariante | A2 erst zum Ohnehin-Zeitpunkt (Kopplungsprinzip) | wie A2, verschoben |

- **Entscheidungsrelevant** ist A2 gegen A1, wenn die Instandsetzung unvermeidbar ist (Kopplungsprinzip: nur die
  Mehrkosten zählen). A2 gegen A0 ist relevant, wenn der Zeitpunkt frei wählbar ist. Das Tool rechnet standardmäßig
  alle drei Alternativen und weist die paarweisen ΔEW aus.
- **Ohnehin-Anteil:** Er geht in A1 und A2 identisch ein und fällt bei gleicher Finanzierbarkeit weitgehend aus
  ΔEW_{A2,A1} heraus (exakt nur bei linearem Ausgleich, siehe 5.2). Wichtig: Bei Vermietern verringert der Instandhaltungsanteil die
  umlagefähigen Modernisierungskosten. Die konkreten Regeln (z. B. Modernisierungsumlage, Drittmittelanrechnung,
  Kappungsgrenzen) sind **volatile Rechtsparameter** und gehören in die YAML-Bibliothek (eigenes Recherche-Memo).

**Perspektivabhängige Zahlungskomponenten der Zahlungsfolge:**

| Komponente | Wohnungsunternehmen / Kleinvermieter | Selbstnutzer |
|---|---|---|
| Investitionsauszahlung (Voll- bzw. Mehrkosten, Baunebenkosten) | ja | ja |
| Förderung (Zuschuss als Zeile ZU, Förderkredit, Tilgungszuschuss) | ja | ja (ggf. alternativ steuerliche Förderung, Slot) |
| Mieteinnahmen bzw. Mehrmiete (Umlage, Mietspiegel, Neuvermietung), Leerstand | ja | – (beim Neubau: ersparte Miete, siehe 5.4) |
| Energiekosten | nur Allgemeinstrom, Leerstand, ggf. Warmmietmodelle | ja (Haupteffekt) |
| CO2-Kosten | Vermieteranteil | voll |
| Instandhaltung, Wartung, Ersatzinvestitionen | ja | ja |
| Restwert bzw. Wertänderung | ja | ja (Vermögenswert, kein Verkauf nötig) |

Optional (ab v1.1): eine **Mieterperspektive** (Warmmietenneutralität: ΔKaltmiete − ΔEnergiekosten des Mieters) als
Zusatzkennzahl. Sie mildert das Mieter-Vermieter-Dilemma nicht, macht es aber sichtbar.

### 5.4 Neubau gegen Bestand; Kaufen gegen Mieten (Privatpersonen)

- **Neubau gegen Bestandserwerb bzw. Bestandssanierung:** unterschiedliche Nutzungsdauern und Instandhaltungsprofile.
  Der Vergleich erfolgt über einen gemeinsamen Horizont mit Restwerten (5.5) und Ersatzinvestitionen im Horizont.
- **Kaufen gegen Mieten (Selbstnutzer):** Es werden **zwei vollständige VoFis** mit identischem Haushaltsbudget
  gerechnet. Die Sparfähigkeit des Haushalts wird in beiden Alternativen als Einlage gebucht. In „Kaufen“ deckt sie
  den Kapitaldienst, in „Mieten“ fließt sie zusammen mit dem EK in die Geldanlage, die Miete ist Auszahlung.
  Verglichen wird das Nettovermögen am Horizont (inkl. Immobilienwert bei „Kaufen“). Diese Form ist für
  Privatpersonen verständlicher als „ersparte Miete“ als Einzahlung. Beide Formen sind bei linearem Ausgleich
  äquivalent.

### 5.5 Horizont, Restwert, Ergänzungs- und Ersatzinvestitionen

**Horizont:** Standard 30 Jahre ab Fertigstellung (Parameter; sinnvoll 20 bis 50). Er muss für alle Alternativen
gleich sein. Für Vergleiche über unterschiedliche Horizonte eignen sich das Entnahme-Äquivalent oder r_EK,mod,
nicht der EW.

**Restwertmethoden** (Parameter `residual_method`; der Restwert erscheint als eigene Teilzeile von z_T):

| Methode | Formel | Einsatz |
|---|---|---|
| `market_growth` | RW_T = V_0·Π(1+g_t)·(1 − c_Verkauf) | einfache Fortschreibung, MC-fähig (g stochastisch) |
| `income_value` | RW_T = (RE_{T+1} − BW·LZ)·(1 − (1+LZ)^−RND)/LZ + BW (Ertragswertlogik; ewige Rente: RE_{T+1}/LZ) | Objektbewertung, Wohnungsunternehmen |
| `component` | RW_T = Σ_j K_j · max(0, 1 − (T − t_j)/ND_j) · (I_T / I_{t_j}) | Sanierungsmaßnahmen (bauteilbezogen, Baupreisindex I) |
| `multiplier` | RW_T = Vervielfältiger × Jahresnettokaltmiete_{T+1} | Marktpraxis, schnelle Szenarien |
| `zero` | RW_T = 0 | konservativ; Pflicht-Sensitivität |

**Ersatzinvestitionen:** bauteilweise Zyklen (z. B. Heizung, PV, Fenster, Dach, Fassade) als Auszahlungen in
t_j + m·ND_j innerhalb des Horizonts. Nicht verbrauchte Nutzungsdauer geht anteilig in `component` ein.
Nutzungsdauern sind Parameter (YAML).

---

## 6. Immobilienwirtschaftliche Kennzahlen

| Kennzahl | Formel | Hinweise |
|---|---|---|
| **Reinertrag / NOI** | NOI_t = Sollmiete_t·(1 − Leerstand_t) − nicht umlagefähige Bewirtschaftungskosten_t (Verwaltung, Instandhaltung, nicht umlegbare Betriebskosten, Mietausfallwagnis, CO2-Vermieteranteil) | vor Kapitaldienst und vor Steuern; Basis für DSCR, ICR, Cash-on-Cash |
| **DSCR** (Kapitaldienstdeckungsgrad) | DSCR_t = NOI_t / KD_t mit KD_t = Σ_k (Z_k,t + T_k,t) | planmäßiger Kapitaldienst **ohne** Sondertilgung und ohne Schlusstilgung endfälliger Darlehen (Refinanzierungsannahme; Fälligkeit wird gesondert geflaggt), ohne KK. Ausweis je Jahr: Minimum, Mittelwert, Anzahl Jahre < Schwelle. Schwelle als Parameter (Bankpraxis häufig 1,1 bis 1,3; institutsabhängig, nicht verifiziert) |
| **ICR** (Zinsdeckungsgrad) | ICR_t = NOI_t / Σ_k Z_k,t | |
| **LTV** | LTV_t = (Σ_k B_k,t [+ KK_t]) / V_t | Variante mit und ohne KK. V_t = Marktwertpfad |
| **Beleihungsauslauf** | BA_t = Σ_k B_k,t / BW_t mit Beleihungswert BW_t = V_t·(1 − Sicherheitsabschlag) | Beleihungswert nach BelWertV. Pfandbriefgrenze 60 % des Beleihungswerts (§ 14 PfandBG) als Referenzlinie |
| **LTC** | Σ Kreditzusagen / Gesamtinvestitionskosten | Projektentwicklung, Neubau |
| **Cash-on-Cash** | CoC_t = (NOI_t − KD_t) / EK_0 (bzw. / kumulierte Einlagen) | laufende Barrendite vor Steuern; bei EK_0 = 0 nicht definiert |
| **Brutto- / Nettoanfangsrendite** | BAR = Jahresnettokaltmiete_1 / Kaufpreis; NAR = NOI_1 / (Kaufpreis + Erwerbsnebenkosten) | statische Marktkennzahlen |
| **Mindestliquidität** | Nebenbedingung G_t ≥ L_min,t; Kennzahlen min_t (G_t − KK_t), max_t KK_t, Summe Nachschüsse, Flags | L_min als Parameter (z. B. Monatsmieten oder fester Betrag) |
| **Break-even-Miete (VoFi)** | m*: ΔEW(m*) = 0 (Anfangsmiete €/m²·Monat bei gegebener Mietentwicklung) | Wurzelsuche (monoton in m). Ebenso Zielrenditemiete: r_EK,mod(m) = r_Ziel |
| **Liquiditäts-Break-even** | m_L: min_t (NOI_t − KD_t) = 0 bzw. DSCR_min = 1 | Beispiel (c): VoFi-Break-even-NOI_1 = 9.869,14, Liquiditäts-Break-even = 17.400,00 |
| **Kritische Werte** | x*: ΔEW(x*) = 0 für x ∈ {Investitionskosten, Miete, Energiepreis, Anschlusszins, Leerstand, Restwertfaktor, Förderquote, h} | Wurzelsuche mit Bracketing. Monotonie prüfen, sonst Warnung |
| **Kostenmiete (statisch, II. BV)** | KM = laufende Aufwendungen / (Wohnfläche·12). Laufende Aufwendungen = Fremdkapitalzinsen + EK-Verzinsung (§ 20) + Abschreibung (§ 25: 1 % der Baukosten) + Verwaltung (§ 26) + Instandhaltung (§ 28) + Mietausfallwagnis (§ 29: 2 % der Erträge) + nicht umgelegte Betriebskosten | rechtlich relevant nur für preisgebundenen Wohnraum bzw. Förderrecht; sonst Vergleichsgröße. Mietausfallwagnis bezogen auf Erträge: Aufwendungen ohne MAW / (1 − 0,02) |
| **Dynamische kostendeckende Miete** | m mit r_EK,mod(m) = r_Ziel (bzw. ΔEW = 0 bei h = r_Ziel) | VoFi-konsistente Alternative zur Kostenmiete |
| **Belastungsquote (privat)** | (KD_t + Bewirtschaftung_t) / Haushaltsnettoeinkommen_t | Tragfähigkeit für Selbstnutzer; Schwelle als Parameter |
| **Effizienzkennzahlen Sanierung** | Kosten je eingesparter kWh = Annuität der Mehrkosten / ΔkWh; CO2-Vermeidungskosten = −Entnahme-Äquivalent(ΔEW) / ΔtCO2 | optional für Portfoliosteuerung |

**Parameter der II. BV ab 01.01.2026** (Sekundärquelle: Merkblatt der Thüringer Aufbaubank 06.2026, Anlage;
Anpassung nach VPI Okt. 2022 bis Okt. 2025, +8,37 %, nächste Anpassung 01.01.2029). Die amtliche Bekanntmachung wurde
nicht eingesehen, daher **vor produktiver Nutzung verifizieren**:

| Position | Wert ab 01.01.2026 |
|---|---|
| Verwaltungskosten je Wohnung und Jahr (§ 26) | 372,46 € |
| Verwaltungskosten je Garage bzw. Einzelstellplatz und Jahr | 48,58 € |
| Instandhaltung je m² Wohnfläche und Jahr, Bezugsfertigkeit < 22 Jahre (§ 28) | 11,50 € |
| … mindestens 22 Jahre | 14,58 € |
| … mindestens 32 Jahre | 18,62 € |
| Zuschlag Aufzug / Abschlag kleine Instandhaltungen durch Mieter | +1,63 € / −1,70 € je m² |
| EK-Verzinsung § 20 Abs. 2 II. BV (geförderter Wohnungsbau) | 4 % für Eigenleistungen bis 15 % der Gesamtkosten, 6,5 % darüber; sonst marktüblicher Zins erster Hypotheken |

*Rechenbeispiel Kostenmiete (illustrativ):* 10 WE, 750 m², Gesamtkosten 3,0 Mio. € (Baukosten 2,5 Mio. €), FK 2,4 Mio. €
zu 3,5 % (84.000 €), EK 0,6 Mio. € (15 % der Gesamtkosten = 450.000 € zu 4 % plus 150.000 € zu 6,5 % = 27.750 €),
AfA 25.000 €, Verwaltung 3.724,60 €, Instandhaltung 8.625,00 €. Zwischensumme 149.099,60 €, Erträge inkl.
Mietausfallwagnis 149.099,60/0,98 = 152.142,45 € (MAW 3.042,85 €). **Kostenmiete = 16,90 €/m²·Monat.**

---

## 7. Periodizität

| Option | Beschreibung | Vorteile | Nachteile |
|---|---|---|---|
| A jährlich durchgehend (Grob-Standard) | Δ_t = 1 | einfach, Tabellen kompakt | Bauphase grob (Bauzeitzinsen, Teilvalutierung, Bereitstellungsprovision ungenau); Monatsraten nur aggregiert |
| B monatlich durchgehend | Δ_t = 1/12, 360 bis 600 Perioden | maximal genau | große Tabellen, KPI-Aggregation nötig, MC-Laufzeit ×12 |
| C jährlich + vorgeschaltetes Bauphasenmodell | Bauphase separat, Ergebnis als I_0 am Fertigstellungszeitpunkt | genau und kompakt | zwei Rechenlogiken; Liquiditätsausgleich und Kennzahlen der Bauphase getrennt; EK-Rendite-Zeitbasis uneinheitlich |
| **D nicht äquidistantes Raster (Empfehlung)** | Vektor Δ_t, z. B. 12 bis 36 Monatsperioden Bauphase, danach Jahresperioden | eine Engine, genaue Bauphase, kompakte Betriebsphase; Zinssätze sind ohnehin Periodenvektoren | Zinsumrechnung je Periode; Kennzahlen jahresbezogen aggregieren |

**Empfehlung D, Details:**

1. Das Raster wird aus Kalenderangaben erzeugt (Baubeginn, Bauzeit in Monaten, Fertigstellung, Horizont in Jahren).
   Standard: Bauphase **monatlich**, Betrieb **jährlich**. Quartale sind optional.
2. **Kreditmodule** rechnen in ihrer **Vertragsfrequenz** (z. B. monatliche Annuität beim KfW-Kredit 261) und
   aggregieren Zinsen und Tilgung auf die VoFi-Periode (Testfall (f)). Sondertilgungen gibt es nur an VoFi-Periodenenden.
3. **Konten** (Anlage, KK) verzinsen je VoFi-Periode mit (1+i_eff)^Δ_t − 1.
4. **Unterjährige Zahlungsströme** (Monatsmieten) werden am Periodenende gebucht. Der Fehler (entgangene bzw.
   ersparte Zinsen) beträgt bei 12 gleichen Monatszahlungen etwa 0,458·h·Jahresbetrag (bei h = 2 % rund 0,9 % des
   Jahresbetrags) und ist dokumentiert. Wer es genauer braucht, verfeinert das Raster.
5. **Kennzahlen:** Zeitbasis in Jahren (τ_T). DSCR, CoC usw. je Kalender- bzw. Betriebsjahr (Summe der Teilperioden).
   Die Amortisation wird in Jahren mit Dezimalstellen ausgewiesen.
6. t = 0 ist der Baubeginn bzw. die Investitionsentscheidung. Der Horizont zählt ab Fertigstellung (Parameter).

---

## 8. Nominal- und Realrechnung

```text
Eingaben in Preisen des Basisjahres x_0 und Steigerungsraten:
    x_t^nom = x_0 · Π_{u≤t} (1 + g_u^nom),   (1 + g^nom) = (1 + g^real)·(1 + π)
Rechnung: vollständig nominal (Kredite, Zinsen, Mieten, Kosten, Restwert)
Ausgabe real:  EW^real = EW^nom / Π_{u≤T}(1+π_u)
               r^real  = (1 + r^nom)/(1 + π̄) − 1,  π̄ = (Π(1+π_u))^(1/T_J) − 1
Beispiel (a), π = 2 %:  EW^real = 38.504,63/1,02^5 = 34.874,83;  r_EK^real = 1,051183/1,02 − 1 = 3,06 %
```

- **Kein Mischen:** Nominale Zahlungen dürfen nicht mit realen Zinsen diskontiert werden und umgekehrt. Weil der VoFi
  nicht diskontiert, sondern aufzinst und ausgleicht, tritt der Fehler typischerweise bei Eingaben auf (z. B. reale
  Energiepreissteigerung bei nominalen Kreditzinsen). Die Eingabemaske verlangt deshalb ausdrücklich „nominal“ oder
  „real + Inflation“.
- **Realwerteffekt der Schulden:** Nur die Nominalrechnung zeigt, dass Inflation feste Nominalschulden real
  entwertet (relevant für Leverage und Selbstnutzer).
- **MC:** Die Inflation ist ein gemeinsamer Treiber mit Korrelation zu Zinsen (Anschlusszins, h, s), Mietindexierung
  und Baupreisindex. Das wird im MC-Memo spezifiziert. Die Engine akzeptiert dafür Pfade je Periode.

---

## 9. Hinweise für den R-Rechenkern (Design, kein Code)

| Baustein | Vorschlag |
|---|---|
| Raster | `grid`: Periodenlängen Δ_t (Jahre), Kalenderdaten, Phasenkennung (`construction`/`operation`) |
| Eingaben | Zahlungsfolge als benannte Komponenten (Matrix n_sim × (T+1) je Komponente), Einlagen und Entnahmen, Zuschüsse, Kreditliste (Spezifikation je Kredit), Konten (h_t, s_t, Limit, L_min, Policy), Optionen (Sondertilgung, Rundung), `tax_fun = NULL` |
| Kern | `vofi_run()`: Periodenschleife nach 3.3, vektorisiert. Liefert Long-Format `row_key × period × sim` sowie Bestände und Flags |
| Unterlassung | `vofi_opportunity()`: gleiche EK-Ströme, keine Investition |
| Kennzahlen | `vofi_kpis()`: EW, ΔEW, R1/R2/R3 mit NA-Codes, r_GK, Amortisation (3 Varianten), DSCR/ICR/LTV/CoC, Liquidität |
| Solver | `vofi_solve()`: Entnahme-Äquivalent, Break-even, kritische Werte (Bisektion bzw. `uniroot`, vektorisierte Bisektion für MC) |
| Vergleich | `vofi_compare()`: mehrere Alternativen, gleiche Rahmenbedingungen erzwingen (Validierung), Differenztabelle |
| Anzeige | Label-Tabelle (Schlüssel → deutsche Bezeichnung) als Datei, nicht im Code. Ausgabe als Grob-Tabelle und transponiert |
| Validierung | Konsistenzprüfungen (s ≥ h, Laufzeiten, Summen der Teilauszahlungen = Zusage, Horizont ≥ Bauphase) mit deutschen Fehlermeldungen |
| Tests | Orakel (a) bis (f) und Invarianten I1 bis I6 |

Abhängigkeiten: Der Kern kommt mit Base R aus (Matrizen, `uniroot`). YAML-Parameter über `yaml` (r-cran-yaml),
Tests über `testthat`.

---

## 10. Referenzbeispiele (Testorakel)

### 10.1 Konventionen (gelten für alle Beispiele)

| Nr. | Konvention |
|---|---|
| K1 | Zeitpunkte t = 0…T. Periode t = (t−1, t]. Alle Zahlungen einer Periode fallen im Zeitpunkt t an (nachschüssig). |
| K2 | Vorzeichen in Zahlungszeilen: Zufluss +, Abfluss −. Bestände positiv. „–“ = 0. |
| K3 | Zinsen der Periode t (Kredite, KK, Anlage) auf den Bestand am Ende von t−1 (nach Ausgleich und Tilgungszuschuss). Zahlung bzw. Gutschrift in t. Keine Kapitalisierung von Sollzinsen. Habenzinsen gehen in den Saldo ein und werden über den Ausgleich wieder angelegt. |
| K4 | In t = 0 keine Zinsen. |
| K5 | Kredite: Auszahlungskurs 100 %, Auszahlung des Nennbetrags in der angegebenen Periode, erste Leistung in der Folgeperiode. Laufzeit n ab der ersten Periode nach der letzten Auszahlung, inklusive tilgungsfreier Perioden. In der Fälligkeitsperiode wird der Rest vollständig getilgt. |
| K6 | Annuität aus Laufzeit: A = B·i/(1−(1+i)^−(n−g)). Mit anfänglicher Tilgung: A = D·(i+τ), ohne Laufzeitende, Restschuld am Horizont. |
| K7 | Tilgungszuschuss: Gutschrift am Ende der Periode t_TZ nach der planmäßigen Leistung, zahlungsunwirksam. `shorten_term`: Rate auf Basis des Nennbetrags bleibt. `reduce_installment`: Neuberechnung bei Tilgungsbeginn auf die Restschuld. |
| K8 | Ausgleich: Überschuss → KK tilgen → (nur (a3)) Sondertilgung → Anlage. Defizit → Guthaben auflösen → KK aufnehmen (Limit unbegrenzt; in (c2) Limit 0 mit Policy `equity_call`). L_min = 0. |
| K9 | Steuern = 0. Keine zahlungswirksamen Zuschüsse. Keine Gebühren außer in (e). |
| K10 | EW = BS_T. Restschulden am Horizont werden abgezogen. Der Restwert ist in z_T enthalten und separat angegeben. |
| K11 | Unterlassungsalternative: gleiche Einlagen (inkl. endogener Nachschüsse) und Entnahmen, keine Investition, keine Kredite, gleiche h und s. |
| K12 | Keine Rundung in der Rechnung. Anzeige mit 2 Dezimalstellen, Renditen mit 4 Dezimalstellen in Prozent. Testtoleranz 1e-6 gegen Skriptwerte, 0,005 gegen Tabellenwerte. |
| K13 | Nur (e): Periodenhaben- und KK-Zins (1+i_eff)^Δ − 1, Kreditzins i_nom·Δ, Bereitstellungsprovision 0,75 % je Quartal auf den nicht abgerufenen Betrag ab Periode 2. |
| K14 | Kennzahlen-Zeitbasis T_J in Jahren. Das Entnahme-Äquivalent ist eine konstante Zusatzentnahme in t = 1…T. Die Amortisation verlangt BS_u ≥ BS^U_u für alle u ≥ t. |

### 10.2 Beispiel (a): klassischer Lehrbuch-VoFi

**Eingaben.** Investition I_0 = 100.000 in t = 0. Zahlungsfolge z_1…z_5 = 6.000; 10.000; 30.000; 8.000; 70.000
(z_5 enthält einen Restwert von 40.000). EK_0 = 30.000. Annuitätendarlehen 40.000 zu 6 %, Laufzeit 5 Jahre,
Annuität 9.495,86. Endfälliges Darlehen 30.000 zu 5 %, fällig t = 5. Kontokorrent s = 10 %, Geldanlage h = 3 %.

| Position | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---:|---:|---:|---:|---:|---:|
| Zahlungsfolge z_t | -100.000,00 | 6.000,00 | 10.000,00 | 30.000,00 | 8.000,00 | 70.000,00 |
| EK: Einlage | 30.000,00 | – | – | – | – | – |
| Annuitätendarlehen: Aufnahme | 40.000,00 | – | – | – | – | – |
| Annuitätendarlehen: Tilgung | – | -7.095,86 | -7.521,61 | -7.972,90 | -8.451,28 | -8.958,35 |
| Annuitätendarlehen: Sollzinsen | – | -2.400,00 | -1.974,25 | -1.522,95 | -1.044,58 | -537,50 |
| Endfälliges Darlehen: Aufnahme | 30.000,00 | – | – | – | – | – |
| Endfälliges Darlehen: Tilgung | – | – | – | – | – | -30.000,00 |
| Endfälliges Darlehen: Sollzinsen | – | -1.500,00 | -1.500,00 | -1.500,00 | -1.500,00 | -1.500,00 |
| Kontokorrent: Aufnahme | – | 4.995,86 | 1.495,44 | – | – | – |
| Kontokorrent: Tilgung | – | – | – | -6.491,30 | – | – |
| Kontokorrent: Sollzinsen | – | – | -499,59 | -649,13 | – | – |
| Geldanlage: Anlage | – | – | – | -11.863,72 | – | -29.280,86 |
| Geldanlage: Auflösung | – | – | – | – | 2.639,94 | – |
| Geldanlage: Habenzinsen | – | – | – | – | 355,91 | 276,71 |
| Steuern (Slot, v1 = 0) | – | – | – | – | – | – |
| **Finanzierungssaldo** | – | – | – | – | – | – |
| Bestand Annuitätendarlehen | 40.000,00 | 32.904,14 | 25.382,54 | 17.409,63 | 8.958,35 | – |
| Bestand Endfälliges Darlehen | 30.000,00 | 30.000,00 | 30.000,00 | 30.000,00 | 30.000,00 | – |
| Bestand Kontokorrent | – | 4.995,86 | 6.491,30 | – | – | – |
| Bestand Guthaben | – | – | – | 11.863,72 | 9.223,77 | 38.504,63 |
| **Bestandssaldo** | -70.000,00 | -67.900,00 | -61.873,83 | -35.545,92 | -29.734,58 | 38.504,63 |

**Kennzahlen Beispiel (a)**

| Kennzahl | Wert |
|---|---:|
| VoFi-Endwert EW | 38.504,63 |
| Endwert Unterlassungsalternative EW_U | 34.778,22 |
| Endwertdifferenz ΔEW = EW − EW_U | 3.726,41 |
| VoFi-EK-Rentabilität klassisch (EW/EK0)^(1/T)−1 | 5,1183 % |
| modifizierte VoFi-EK-Rendite (R3) | 5,1183 % |
| Equity-IRR der EK-Zahlungen (R2) | 5,1183 % |
| VoFi-Amortisationszeitpunkt (mit Restwert) | 5 |
| VoFi-Amortisationszeitpunkt (ohne Restwert) | keine im Horizont |
| min. Nettoliquidität min(G_t − KK_t) | -6.491,30 |
| max. Kontokorrentstand | 6.491,30 |
| Entnahme-Äquivalent (VoFi-Annuität, exakt) | 672,44 |
| Näherung ΔEW·h/((1+h)^T−1) | 701,89 |
| Kapitalwert der Zahlungsfolge bei 3 % | 10.195,96 |
| Kapitalwert der Zahlungsfolge bei 10 % | -14.812,95 |
| Interner Zinsfuß der Zahlungsfolge | 5,5636 % |
| Bestandssaldo Unterlassungsalternative je t | 30.000,00; 30.900,00; 31.827,00; 32.781,81; 33.765,26; 34.778,22 |
| EW eigenfinanziert (EK = 100.000, keine Kredite) | 127.747,32 |
| VoFi-Gesamtkapitalrendite (eigenfinanziert) | 5,0196 % |

Kontrolle: EW bei Entnahme E* = 34.778,22 (soll = EW_U)

Kontrolle: max|Finanzierungssaldo| = 0.0e+00; max. Abweichung Vermögensfortschreibung = 7.3e-12

**Lesart.** In t = 1 und t = 2 entstehen Defizite, die das Kontokorrent deckt. Die KK-Zinsen fallen erst in t = 2
auf den Bestand von t = 1 an (K3). In t = 3 tilgt der Überschuss zuerst das KK (Ü1), der Rest wird angelegt (Ü4). In
t = 4 wird das Defizit durch Auflösung des Guthabens gedeckt (D1). In t = 5 zahlen Restwert und Überschuss das
endfällige Darlehen zurück. Der IZF der Zahlungsfolge (5,56 %) liegt über der eigenfinanzierten
VoFi-Gesamtkapitalrendite (5,02 %), weil der IZF implizit Wiederanlage zu 5,56 % unterstellt, der VoFi aber die
tatsächliche Anlage zu 3 %. Die VoFi-EK-Rentabilität (5,12 %) enthält zusätzlich den hier leicht positiven
Leverage-Effekt (Kredite zu 5 % bzw. 6 %, KK zu 10 %). Der Kapitalwert bei 3 % (10.195,96) ist mit ΔEW = 3.726,41 nicht vergleichbar: Er gilt für vollständige
Eigenfinanzierung zu 3 %. Der eigenfinanzierte VoFi liefert ΔEW_GK = 127.747,32 − 100.000·1,03^5 = 11.819,92
= KW_3%·1,03^5 (Invariante I4, da dort kein KK benötigt wird).

#### (a3) Variante: Sondertilgungsregel Ü3 für das Annuitätendarlehen (6 % > h = 3 %)

| Position | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---:|---:|---:|---:|---:|---:|
| Zahlungsfolge z_t | -100.000,00 | 6.000,00 | 10.000,00 | 30.000,00 | 8.000,00 | 70.000,00 |
| EK: Einlage | 30.000,00 | – | – | – | – | – |
| Annuitätendarlehen: Aufnahme | 40.000,00 | – | – | – | – | – |
| Annuitätendarlehen: Tilgung | – | -7.095,86 | -7.521,61 | -7.972,90 | -5.545,92 | – |
| Annuitätendarlehen: Sondertilgung | – | – | – | -11.863,72 | – | – |
| Annuitätendarlehen: Sollzinsen | – | -2.400,00 | -1.974,25 | -1.522,95 | -332,75 | – |
| Endfälliges Darlehen: Aufnahme | 30.000,00 | – | – | – | – | – |
| Endfälliges Darlehen: Tilgung | – | – | – | – | – | -30.000,00 |
| Endfälliges Darlehen: Sollzinsen | – | -1.500,00 | -1.500,00 | -1.500,00 | -1.500,00 | -1.500,00 |
| Kontokorrent: Aufnahme | – | 4.995,86 | 1.495,44 | – | – | – |
| Kontokorrent: Tilgung | – | – | – | -6.491,30 | – | – |
| Kontokorrent: Sollzinsen | – | – | -499,59 | -649,13 | – | – |
| Geldanlage: Anlage | – | – | – | – | -621,33 | -38.518,64 |
| Geldanlage: Auflösung | – | – | – | – | – | – |
| Geldanlage: Habenzinsen | – | – | – | – | – | 18,64 |
| Steuern (Slot, v1 = 0) | – | – | – | – | – | – |
| **Finanzierungssaldo** | – | – | – | – | – | – |
| Bestand Annuitätendarlehen | 40.000,00 | 32.904,14 | 25.382,54 | 5.545,92 | – | – |
| Bestand Endfälliges Darlehen | 30.000,00 | 30.000,00 | 30.000,00 | 30.000,00 | 30.000,00 | – |
| Bestand Kontokorrent | – | 4.995,86 | 6.491,30 | – | – | – |
| Bestand Guthaben | – | – | – | – | 621,33 | 39.139,97 |
| **Bestandssaldo** | -70.000,00 | -67.900,00 | -61.873,83 | -35.545,92 | -29.378,67 | 39.139,97 |

**Kennzahlen Beispiel (a3)**

| Kennzahl | Wert |
|---|---:|
| VoFi-Endwert EW | 39.139,97 |
| Endwert Unterlassungsalternative EW_U | 34.778,22 |
| Endwertdifferenz ΔEW = EW − EW_U | 4.361,75 |
| VoFi-EK-Rentabilität klassisch (EW/EK0)^(1/T)−1 | 5,4629 % |
| modifizierte VoFi-EK-Rendite (R3) | 5,4629 % |
| Equity-IRR der EK-Zahlungen (R2) | 5,4629 % |
| VoFi-Amortisationszeitpunkt (mit Restwert) | 5 |
| VoFi-Amortisationszeitpunkt (ohne Restwert) | keine im Horizont |
| min. Nettoliquidität min(G_t − KK_t) | -6.491,30 |
| max. Kontokorrentstand | 6.491,30 |

Kontrolle: max|Finanzierungssaldo| = 9.1e-13; max. Abweichung Vermögensfortschreibung = 7.3e-12

**Lesart.** Der Überschuss in t = 3 (nach KK-Tilgung 11.863,72) tilgt das 6 %-Darlehen außerplanmäßig, statt zu 3 %
angelegt zu werden. Die Annuität bleibt gleich, daher ist das Darlehen in t = 4 vollständig getilgt (Restzahlung
5.545,92 + 332,75 Zinsen). Der EW steigt um 635,34. Hätte die Sondertilgung später KK-Bedarf zu 10 % ausgelöst,
wäre die Regel nachteilig (siehe 3.2).

### 10.3 Beispiel (b): Ratentilgung, tilgungsfreie Anlaufjahre, Tilgungszuschuss

**Eingaben** (energetische Sanierung eines Mehrfamilienhauses, Unternehmensperspektive, stilisiert):
Vollkosten 200.000 in t = 0. Einzahlungsüberschüsse z_t = 14.000·1,02^(t−1), t = 1…10 (Mehrmiete und vermiedene
Instandhaltung). Restwert der Maßnahme 60.000 in t = 10. EK_0 = 50.000. Förderdarlehen 150.000 zu 2,0 % p. a.,
jährliche Zahlung, Laufzeit 10 Jahre, davon 2 tilgungsfreie Anlaufjahre, danach Ratentilgung. Tilgungszuschuss 15 %
= 22.500, Gutschrift am Ende von t = 1. h = 2 %, s = 8 %.

*Hinweis:* Beim KfW-Wohngebäudekredit 261 gibt es laut Programmseite Annuitätendarlehen mit monatlichen Raten und
endfällige Darlehen. Die Ratentilgung ist hier ein **methodischer Test** (sie kommt z. B. bei anderen Förder- oder
Kommunaldarlehen vor). Für den KfW-Fall gilt dieselbe Logik mit `kind = annuity`.

#### (b1) Tilgungszuschuss verkürzt die Laufzeit (`shorten_term`, Standard)

| Position | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Zahlungsfolge z_t | -200.000,00 | 14.000,00 | 14.280,00 | 14.565,60 | 14.856,91 | 15.154,05 | 15.457,13 | 15.766,27 | 16.081,60 | 16.403,23 | 76.731,30 |
| EK: Einlage | 50.000,00 | – | – | – | – | – | – | – | – | – | – |
| Förderdarlehen: Aufnahme | 150.000,00 | – | – | – | – | – | – | – | – | – | – |
| Förderdarlehen: Tilgung | – | – | – | -18.750,00 | -18.750,00 | -18.750,00 | -18.750,00 | -18.750,00 | -18.750,00 | -15.000,00 | – |
| Förderdarlehen: Sollzinsen | – | -3.000,00 | -2.550,00 | -2.550,00 | -2.175,00 | -1.800,00 | -1.425,00 | -1.050,00 | -675,00 | -300,00 | – |
| Kontokorrent: Aufnahme | – | – | – | – | – | – | – | 2.850,28 | 3.571,42 | – | – |
| Kontokorrent: Tilgung | – | – | – | – | – | – | – | – | – | -589,50 | -5.832,21 |
| Kontokorrent: Sollzinsen | – | – | – | – | – | – | – | – | -228,02 | -513,74 | -466,58 |
| Geldanlage: Anlage | – | -11.000,00 | -11.950,00 | – | – | – | – | – | – | – | -70.432,51 |
| Geldanlage: Auflösung | – | – | – | 6.275,40 | 5.734,60 | 5.177,15 | 4.602,61 | 1.160,24 | – | – | – |
| Geldanlage: Habenzinsen | – | – | 220,00 | 459,00 | 333,49 | 218,80 | 115,26 | 23,20 | – | – | – |
| Steuern (Slot, v1 = 0) | – | – | – | – | – | – | – | – | – | – | – |
| **Finanzierungssaldo** | – | – | – | – | – | – | – | – | – | – | – |
| Förderdarlehen: Tilgungszuschuss (zahlungsunwirksam) | – | 22.500,00 | – | – | – | – | – | – | – | – | – |
| Bestand Förderdarlehen | 150.000,00 | 127.500,00 | 127.500,00 | 108.750,00 | 90.000,00 | 71.250,00 | 52.500,00 | 33.750,00 | 15.000,00 | – | – |
| Bestand Kontokorrent | – | – | – | – | – | – | – | 2.850,28 | 6.421,70 | 5.832,21 | – |
| Bestand Guthaben | – | 11.000,00 | 22.950,00 | 16.674,60 | 10.940,00 | 5.762,85 | 1.160,24 | – | – | – | 70.432,51 |
| **Bestandssaldo** | -150.000,00 | -116.500,00 | -104.550,00 | -92.075,40 | -79.060,00 | -65.487,15 | -51.339,76 | -36.600,28 | -21.421,70 | -5.832,21 | 70.432,51 |

**Kennzahlen Beispiel (b1) Tilgungszuschuss verkürzt Laufzeit**

| Kennzahl | Wert |
|---|---:|
| VoFi-Endwert EW | 70.432,51 |
| Endwert Unterlassungsalternative EW_U | 60.949,72 |
| Endwertdifferenz ΔEW = EW − EW_U | 9.482,79 |
| VoFi-EK-Rentabilität klassisch (EW/EK0)^(1/T)−1 | 3,4857 % |
| modifizierte VoFi-EK-Rendite (R3) | 3,4857 % |
| Equity-IRR der EK-Zahlungen (R2) | 3,4857 % |
| VoFi-Amortisationszeitpunkt (mit Restwert) | 10 |
| VoFi-Amortisationszeitpunkt (ohne Restwert) | keine im Horizont |
| min. Nettoliquidität min(G_t − KK_t) | -6.421,70 |
| max. Kontokorrentstand | 6.421,70 |
| Entnahme-Äquivalent (exakt) | 731,23 |
| DSCR_t (t=1..10) | 4,67; 5,60; 0,68; 0,71; 0,74; 0,77; 0,80; 0,83; 1,07; n. d. |
| Kapitalwert z bei 2 % | -13.524,20 |
| IZF z | 0,9458 % |

Kontrolle: max|Finanzierungssaldo| = 0.0e+00; max. Abweichung Vermögensfortschreibung = 7.3e-12

#### (b2) Tilgungszuschuss senkt die Tilgungsrate (`reduce_installment`)

| Position | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Zahlungsfolge z_t | -200.000,00 | 14.000,00 | 14.280,00 | 14.565,60 | 14.856,91 | 15.154,05 | 15.457,13 | 15.766,27 | 16.081,60 | 16.403,23 | 76.731,30 |
| EK: Einlage | 50.000,00 | – | – | – | – | – | – | – | – | – | – |
| Förderdarlehen: Aufnahme | 150.000,00 | – | – | – | – | – | – | – | – | – | – |
| Förderdarlehen: Tilgung | – | – | – | -15.937,50 | -15.937,50 | -15.937,50 | -15.937,50 | -15.937,50 | -15.937,50 | -15.937,50 | -15.937,50 |
| Förderdarlehen: Sollzinsen | – | -3.000,00 | -2.550,00 | -2.550,00 | -2.231,25 | -1.912,50 | -1.593,75 | -1.275,00 | -956,25 | -637,50 | -318,75 |
| Kontokorrent: Aufnahme | – | – | – | – | – | – | – | – | – | – | – |
| Kontokorrent: Tilgung | – | – | – | – | – | – | – | – | – | – | – |
| Kontokorrent: Sollzinsen | – | – | – | – | – | – | – | – | – | – | – |
| Geldanlage: Anlage | – | -11.000,00 | -11.950,00 | – | – | – | – | – | – | -40,72 | -60.688,35 |
| Geldanlage: Auflösung | – | – | – | 3.462,90 | 2.922,10 | 2.364,65 | 1.790,11 | 1.198,02 | 587,91 | – | – |
| Geldanlage: Habenzinsen | – | – | 220,00 | 459,00 | 389,74 | 331,30 | 284,01 | 248,20 | 224,24 | 212,49 | 213,30 |
| Steuern (Slot, v1 = 0) | – | – | – | – | – | – | – | – | – | – | – |
| **Finanzierungssaldo** | – | – | – | – | – | – | – | – | – | – | – |
| Förderdarlehen: Tilgungszuschuss (zahlungsunwirksam) | – | 22.500,00 | – | – | – | – | – | – | – | – | – |
| Bestand Förderdarlehen | 150.000,00 | 127.500,00 | 127.500,00 | 111.562,50 | 95.625,00 | 79.687,50 | 63.750,00 | 47.812,50 | 31.875,00 | 15.937,50 | – |
| Bestand Kontokorrent | – | – | – | – | – | – | – | – | – | – | – |
| Bestand Guthaben | – | 11.000,00 | 22.950,00 | 19.487,10 | 16.565,00 | 14.200,35 | 12.410,24 | 11.212,22 | 10.624,32 | 10.665,03 | 71.353,38 |
| **Bestandssaldo** | -150.000,00 | -116.500,00 | -104.550,00 | -92.075,40 | -79.060,00 | -65.487,15 | -51.339,76 | -36.600,28 | -21.250,68 | -5.272,47 | 71.353,38 |

**Kennzahlen Beispiel (b2) Tilgungszuschuss senkt Tilgungsrate**

| Kennzahl | Wert |
|---|---:|
| VoFi-Endwert EW | 71.353,38 |
| Endwert Unterlassungsalternative EW_U | 60.949,72 |
| Endwertdifferenz ΔEW = EW − EW_U | 10.403,66 |
| VoFi-EK-Rentabilität klassisch (EW/EK0)^(1/T)−1 | 3,6202 % |
| modifizierte VoFi-EK-Rendite (R3) | 3,6202 % |
| Equity-IRR der EK-Zahlungen (R2) | 3,6202 % |
| VoFi-Amortisationszeitpunkt (mit Restwert) | 10 |
| VoFi-Amortisationszeitpunkt (ohne Restwert) | keine im Horizont |
| min. Nettoliquidität min(G_t − KK_t) | – |
| max. Kontokorrentstand | – |
| Entnahme-Äquivalent (exakt) | 950,13 |
| DSCR_t (t=1..10) | 4,67; 5,60; 0,79; 0,82; 0,85; 0,88; 0,92; 0,95; 0,99; 1,03 |
| Kapitalwert z bei 2 % | -13.524,20 |
| IZF z | 0,9458 % |

Kontrolle: max|Finanzierungssaldo| = 0.0e+00; max. Abweichung Vermögensfortschreibung = 7.3e-12

**Lesart.**
- (b1): Die Tilgungsrate bleibt bei 18.750 (Basis Nennbetrag), der Kredit ist in t = 9 getilgt (Restrate 15.000).
  Die hohe Tilgung ab t = 3 übersteigt die Überschüsse. Das Guthaben ist in t = 7 aufgebraucht, danach
  entsteht KK-Bedarf zu 8 % (max. 6.421,70). Der DSCR liegt in t = 3…8 unter 1.
- (b2): Die Rate sinkt auf 127.500/8 = 15.937,50. Es entsteht kein KK-Bedarf, und **EW ist um 920,87 höher** als in
  (b1). Die Laufzeitverkürzung zahlt den günstigen 2 %-Kredit schneller zurück und erzwingt teures KK.
- **Konsistenztest I4 in (b2):** Kredit, Anlage und (nicht benötigtes) KK-Umfeld wirken wie ein vollkommener Markt
  zu 2 %. Daher ΔEW = (KW_2%(z) + 22.500/1,02)·1,02^10 = (−13.524,20 + 22.058,82)·1,218994 = **10.403,66**. Der
  klassische Kapitalwert der Zahlungsfolge (−13.524,20) und der IZF (0,95 %) würden die Maßnahme verwerfen, weil der
  Fördervorteil auf der Finanzierungsseite liegt.

### 10.4 Beispiel (c): 100 % Fremdfinanzierung

**Eingaben** (Kleinvermieter, Neubau-Eigentumswohnung, stilisiert): Gesamtinvestition 300.000 in t = 0 (inkl.
Nebenkosten), Marktwert V_0 = 280.000, Wertsteigerung 2 % p. a. NOI_t = 12.000·1,02^(t−1). Restwert in t = 10
= V_10·(1 − 3 % Verkaufskosten) = 331.078,88. EK_0 = 0. Annuitätendarlehen 300.000, Sollzins 3,8 %, anfängliche
Tilgung 2 %, jährliche Annuität 17.400, Zinsbindung ≥ Horizont, Restschuld am Horizont. h = 2,5 %, s = 9 %.

#### (c1) Defizite über Kontokorrent (Limit unbegrenzt)

| Position | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Zahlungsfolge z_t | -300.000,00 | 12.000,00 | 12.240,00 | 12.484,80 | 12.734,50 | 12.989,19 | 13.248,97 | 13.513,95 | 13.784,23 | 14.059,91 | 345.420,00 |
| EK: Einlage | – | – | – | – | – | – | – | – | – | – | – |
| Annuitätendarlehen: Aufnahme | 300.000,00 | – | – | – | – | – | – | – | – | – | – |
| Annuitätendarlehen: Tilgung | – | -6.000,00 | -6.228,00 | -6.464,66 | -6.710,32 | -6.965,31 | -7.230,00 | -7.504,74 | -7.789,92 | -8.085,93 | -8.393,20 |
| Annuitätendarlehen: Sollzinsen | – | -11.400,00 | -11.172,00 | -10.935,34 | -10.689,68 | -10.434,69 | -10.170,00 | -9.895,26 | -9.610,08 | -9.314,07 | -9.006,80 |
| Kontokorrent: Aufnahme | – | 5.400,00 | 5.646,00 | 5.909,34 | 6.191,48 | 6.494,03 | 6.818,71 | 7.167,41 | 7.542,20 | 7.945,31 | – |
| Kontokorrent: Tilgung | – | – | – | – | – | – | – | – | – | – | -59.114,48 |
| Kontokorrent: Sollzinsen | – | – | -486,00 | -994,14 | -1.525,98 | -2.083,21 | -2.667,68 | -3.281,36 | -3.926,43 | -4.605,23 | -5.320,30 |
| Geldanlage: Anlage | – | – | – | – | – | – | – | – | – | – | -263.585,21 |
| Geldanlage: Auflösung | – | – | – | – | – | – | – | – | – | – | – |
| Geldanlage: Habenzinsen | – | – | – | – | – | – | – | – | – | – | – |
| Steuern (Slot, v1 = 0) | – | – | – | – | – | – | – | – | – | – | – |
| **Finanzierungssaldo** | – | – | – | – | – | – | – | – | – | – | – |
| Bestand Annuitätendarlehen | 300.000,00 | 294.000,00 | 287.772,00 | 281.307,34 | 274.597,01 | 267.631,70 | 260.401,71 | 252.896,97 | 245.107,06 | 237.021,12 | 228.627,93 |
| Bestand Kontokorrent | – | 5.400,00 | 11.046,00 | 16.955,34 | 23.146,82 | 29.640,85 | 36.459,56 | 43.626,97 | 51.169,17 | 59.114,48 | – |
| Bestand Guthaben | – | – | – | – | – | – | – | – | – | – | 263.585,21 |
| **Bestandssaldo** | -300.000,00 | -299.400,00 | -298.818,00 | -298.262,68 | -297.743,84 | -297.272,55 | -296.861,27 | -296.523,94 | -296.276,23 | -296.135,61 | 34.957,28 |

**Kennzahlen Beispiel (c1)**

| Kennzahl | Wert |
|---|---:|
| VoFi-Endwert EW | 34.957,28 |
| Endwert Unterlassungsalternative EW_U | – |
| Endwertdifferenz ΔEW = EW − EW_U | 34.957,28 |
| VoFi-EK-Rentabilität klassisch (EW/EK0)^(1/T)−1 | n. d. |
| modifizierte VoFi-EK-Rendite (R3) | n. d. |
| Equity-IRR der EK-Zahlungen (R2) | n. d. |
| VoFi-Amortisationszeitpunkt (mit Restwert) | 10 |
| VoFi-Amortisationszeitpunkt (ohne Restwert) | keine im Horizont |
| min. Nettoliquidität min(G_t − KK_t) | -59.114,48 |
| max. Kontokorrentstand | 59.114,48 |
| DSCR_t | 0,69; 0,70; 0,72; 0,73; 0,75; 0,76; 0,78; 0,79; 0,81; 0,82 |
| LTV_t (inkl. KK) | 107,14 %; 104,83 %; 102,58 %; 100,38 %; 98,24 %; 96,16 %; 94,14 %; 92,19 %; 90,31 %; 88,50 %; 66,98 % |
| Restwert netto (V_T·0,97) | 331.078,88 |
| Entnahme-Äquivalent (exakt) | 2.300,89 |
| Break-even-NOI_1 (ΔEW = 0) | 9.869,14 |
| Liquiditäts-Break-even-NOI_1 (DSCR_1 = 1) | 17.400,00 |
| Projekt-IZF der Zahlungsfolge | 5,1616 % |
| EW / Investitionsvolumen | 11,65 % |
| EW eigenfinanziert (EK = 300.000) | 477.695,18 |
| VoFi-Gesamtkapitalrendite (eigenfinanziert) | 4,7618 % |

Kontrolle: max|Finanzierungssaldo| = 0.0e+00; max. Abweichung Vermögensfortschreibung = 5.8e-11

#### (c2) Defizite durch Nachschüsse (KK-Limit 0, Policy `equity_call`)

| Position | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Zahlungsfolge z_t | -300.000,00 | 12.000,00 | 12.240,00 | 12.484,80 | 12.734,50 | 12.989,19 | 13.248,97 | 13.513,95 | 13.784,23 | 14.059,91 | 345.420,00 |
| EK: Einlage | – | – | – | – | – | – | – | – | – | – | – |
| EK: Nachschuss (endogen) | – | 5.400,00 | 5.160,00 | 4.915,20 | 4.665,50 | 4.410,81 | 4.151,03 | 3.886,05 | 3.615,77 | 3.340,09 | – |
| Annuitätendarlehen: Aufnahme | 300.000,00 | – | – | – | – | – | – | – | – | – | – |
| Annuitätendarlehen: Tilgung | – | -6.000,00 | -6.228,00 | -6.464,66 | -6.710,32 | -6.965,31 | -7.230,00 | -7.504,74 | -7.789,92 | -8.085,93 | -8.393,20 |
| Annuitätendarlehen: Sollzinsen | – | -11.400,00 | -11.172,00 | -10.935,34 | -10.689,68 | -10.434,69 | -10.170,00 | -9.895,26 | -9.610,08 | -9.314,07 | -9.006,80 |
| Kontokorrent: Aufnahme | – | – | – | – | – | – | – | – | – | – | – |
| Kontokorrent: Tilgung | – | – | – | – | – | – | – | – | – | – | – |
| Kontokorrent: Sollzinsen | – | – | – | – | – | – | – | – | – | – | – |
| Geldanlage: Anlage | – | – | – | – | – | – | – | – | – | – | -328.020,00 |
| Geldanlage: Auflösung | – | – | – | – | – | – | – | – | – | – | – |
| Geldanlage: Habenzinsen | – | – | – | – | – | – | – | – | – | – | – |
| Steuern (Slot, v1 = 0) | – | – | – | – | – | – | – | – | – | – | – |
| **Finanzierungssaldo** | – | – | – | – | – | – | – | – | – | – | – |
| Bestand Annuitätendarlehen | 300.000,00 | 294.000,00 | 287.772,00 | 281.307,34 | 274.597,01 | 267.631,70 | 260.401,71 | 252.896,97 | 245.107,06 | 237.021,12 | 228.627,93 |
| Bestand Kontokorrent | – | – | – | – | – | – | – | – | – | – | – |
| Bestand Guthaben | – | – | – | – | – | – | – | – | – | – | 328.020,00 |
| **Bestandssaldo** | -300.000,00 | -294.000,00 | -287.772,00 | -281.307,34 | -274.597,01 | -267.631,70 | -260.401,71 | -252.896,97 | -245.107,06 | -237.021,12 | 99.392,07 |

**Kennzahlen Beispiel (c2)**

| Kennzahl | Wert |
|---|---:|
| VoFi-Endwert EW | 99.392,07 |
| Endwert Unterlassungsalternative EW_U | 45.263,66 |
| Endwertdifferenz ΔEW = EW − EW_U | 54.128,41 |
| VoFi-EK-Rentabilität klassisch (EW/EK0)^(1/T)−1 | n. d. |
| modifizierte VoFi-EK-Rendite (R3) | 10,8879 % |
| Equity-IRR der EK-Zahlungen (R2) | 16,9699 % |
| VoFi-Amortisationszeitpunkt (mit Restwert) | 10 |
| VoFi-Amortisationszeitpunkt (ohne Restwert) | keine im Horizont |
| min. Nettoliquidität min(G_t − KK_t) | – |
| max. Kontokorrentstand | – |
| Summe endogene Nachschüsse | 39.544,46 |
| Barwert der Nachschüsse bei h | 35.359,90 |

Kontrolle: max|Finanzierungssaldo| = 0.0e+00; max. Abweichung Vermögensfortschreibung = 1.6e-11

**Lesart.**
- (c1): Ohne Eigenkapital ist r_EK **nicht definiert** (Code `no_equity`). Der VoFi zeigt dennoch eindeutig ΔEW =
  EW = 34.957,28 > 0. Der Wert entsteht **ausschließlich über den Restwert**: Der DSCR liegt durchgehend unter 1
  (0,69 bis 0,82), der LTV beginnt bei 107,14 %, der KK-Bedarf wächst auf 59.114,48. Ein Haushalt ohne entsprechenden
  Dispositionsrahmen könnte das nicht tragen. Der VoFi-Break-even des NOI_1 (9.869,14) liegt weit unter dem
  Liquiditäts-Break-even (17.400,00). Rentabilität und Tragfähigkeit fallen hier deutlich auseinander.
- (c2): Werden die Defizite vom Eigentümer nachgeschossen (Summe 39.544,46; Barwert zu h: 35.359,90), entfällt der
  teure KK-Zins. Mit den Nachschüssen als Einlagen ist R3 definiert: **r_EK,mod = 10,89 %**. Der Equity-IRR R2 =
  16,97 % überzeichnet, weil er die späten Nachschüsse mit 16,97 % statt mit dem Opportunitätszins diskontiert.
  ΔEW = 99.392,07 − 45.263,66 = 54.128,41 (Unterlassung: Nachschüsse zu 2,5 % angelegt). Der Unterschied
  ΔEW(c2) − ΔEW(c1) = 19.171,13 ist exakt die Differenz zwischen dem zu 9 % (KK) und dem zu 2,5 % (Opportunität)
  aufgezinsten Finanzierungsbedarf: 64.434,79 (KK-Rückführung inkl. Zinsen in t = 10) − 45.263,66.
- Eigenfinanzierte VoFi-Gesamtkapitalrendite: 4,76 % (EW_GK = 477.695,18 bei EK 300.000), der Projekt-IZF beträgt 5,16 %.

### 10.5 Beispiel (d): Konsistenztest vollkommener Kapitalmarkt

Daten wie in (a), aber **alle Zinssätze 5 %** (beide Kredite, KK, Anlage). Erwartung nach I4:
ΔEW = KW_5%(z)·1,05^5.

| Größe | Wert |
|---|---:|
| EW | 41.004,58 |
| EW_U = 30.000·1,05^5 | 38.288,45 |
| ΔEW | 2.716,13 |
| KW(5 %)·1,05^5 | 2.716,13 |
| KW(5 %) | 2.128,16 |
| Differenz (soll 0) | 1.000e-11 |
| r_EK klassisch | 6,4492 % |

Kontrolle: max|Finanzierungssaldo| = 0.0e+00; max. Abweichung Vermögensfortschreibung = 7.3e-12

### 10.6 Beispiel (e): nicht äquidistantes Raster (Bauphase quartalsweise, Betrieb jährlich)

**Eingaben.** Δ = (¼, ¼, ¼, ¼, 1, 1, 1), Zeit in Jahren τ = 0; 0,25; 0,5; 0,75; 1; 2; 3; 4. Baukosten 200.000 (t = 0),
je 100.000 in t = 1, 2, 3. Fertigstellung in τ = 1. NOI 30.000; 30.600; 31.212 in den Jahren 2 bis 4, Restwert
520.000 in τ = 4. EK_0 = 100.000. Baudarlehen, Zusage 400.000, Teilauszahlungen je 100.000 in t = 0, 1, 2, 3.
Sollzins 3,6 % p. a. nominal (Quartal 0,9 %). Bereitstellungsprovision 0,75 % je Quartal auf den nicht abgerufenen
Betrag ab dem 2. Quartal (Annahme für den Test, nicht als Marktwert belegt; KfW 261: 0,15 % je Monat ab dem
13. Monat). Nach der letzten Auszahlung ein tilgungsfreies Quartal (t = 4), ab t = 5 Jahresannuität
400.000·(3,6 % + 2 %) = 22.400. h_eff = 2,5 %, s_eff = 9 % p. a. (Quartal: 0,6192 % bzw. 2,1778 %).

| Position | 0 | 0,25 | 0,5 | 0,75 | 1 | 2 | 3 | 4 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Zahlungsfolge z_t | -200.000,00 | -100.000,00 | -100.000,00 | -100.000,00 | – | 30.000,00 | 30.600,00 | 551.212,00 |
| EK: Einlage | 100.000,00 | – | – | – | – | – | – | – |
| Baudarlehen: Aufnahme | 100.000,00 | 100.000,00 | 100.000,00 | 100.000,00 | – | – | – | – |
| Baudarlehen: Tilgung | – | – | – | – | – | -8.000,00 | -8.288,00 | -8.586,37 |
| Baudarlehen: Sollzinsen | – | -900,00 | -1.800,00 | -2.700,00 | -3.600,00 | -14.400,00 | -14.112,00 | -13.813,63 |
| Baudarlehen: Bereitstellungsprov. | – | – | -1.500,00 | -750,00 | – | – | – | – |
| Kontokorrent: Aufnahme | – | 900,00 | 3.319,60 | 3.541,90 | 3.769,03 | – | – | – |
| Kontokorrent: Tilgung | – | – | – | – | – | -6.562,25 | -4.968,27 | – |
| Kontokorrent: Sollzinsen | – | – | -19,60 | -91,90 | -169,03 | -1.037,75 | -447,14 | – |
| Geldanlage: Anlage | – | – | – | – | – | – | -2.784,58 | -528.881,61 |
| Geldanlage: Auflösung | – | – | – | – | – | – | – | – |
| Geldanlage: Habenzinsen | – | – | – | – | – | – | – | 69,61 |
| Steuern (Slot, v1 = 0) | – | – | – | – | – | – | – | – |
| **Finanzierungssaldo** | – | – | – | – | – | – | – | – |
| Bestand Baudarlehen | 100.000,00 | 200.000,00 | 300.000,00 | 400.000,00 | 400.000,00 | 392.000,00 | 383.712,00 | 375.125,63 |
| Bestand Kontokorrent | – | 900,00 | 4.219,60 | 7.761,50 | 11.530,53 | 4.968,27 | – | – |
| Bestand Guthaben | – | – | – | – | – | – | 2.784,58 | 531.666,20 |
| **Bestandssaldo** | -100.000,00 | -200.900,00 | -304.219,60 | -407.761,50 | -411.530,53 | -396.968,27 | -380.927,42 | 156.540,56 |

**Kennzahlen Beispiel (e)**

| Kennzahl | Wert |
|---|---:|
| VoFi-Endwert EW | 156.540,56 |
| Endwert Unterlassungsalternative EW_U | 110.381,29 |
| Endwertdifferenz ΔEW = EW − EW_U | 46.159,27 |
| VoFi-EK-Rentabilität klassisch (EW/EK0)^(1/T)−1 | 11,8553 % |
| modifizierte VoFi-EK-Rendite (R3) | 11,8553 % |
| Equity-IRR der EK-Zahlungen (R2) | 11,8553 % |
| VoFi-Amortisationszeitpunkt (mit Restwert) | 4 |
| VoFi-Amortisationszeitpunkt (ohne Restwert) | keine im Horizont |
| min. Nettoliquidität min(G_t − KK_t) | -11.530,53 |
| max. Kontokorrentstand | 11.530,53 |

Periodenzinssätze Haben (t=1..7): 0.0061922463; 0.0061922463; 0.0061922463; 0.0061922463; 0.0250000000; 0.0250000000; 0.0250000000

Periodenzinssätze KK (t=1..7): 0.0217781809; 0.0217781809; 0.0217781809; 0.0217781809; 0.0900000000; 0.0900000000; 0.0900000000

Kontrolle: max|Finanzierungssaldo| = 0.0e+00; max. Abweichung Vermögensfortschreibung = 1.8e-11

**Lesart.** Bauzeitzinsen und Bereitstellungsprovision lösen in der Bauphase KK-Bedarf aus (Quartalssätze). Ab
der Betriebsphase gelten Jahressätze. Die EK-Rentabilität bezieht sich auf T_J = 4 Jahre:
(156.540,56/100.000)^(1/4) − 1 = 11,86 %. EW_U = 100.000·1,025^4 = 110.381,29 (vier Quartale zu 1,025^¼ und drei
Jahre).

### 10.7 Test (f): Monatsannuität, aggregiert auf eine Jahresperiode

Darlehen 100.000, Sollzins 3,6 % p. a. nominal, monatliche Annuität, Laufzeit 240 Monate. Das Kreditmodul rechnet
monatlich (0,3 % je Monat) und liefert für die VoFi-Jahresperiode die Summen:

| Größe | Wert |
|---|---:|
| Monatsrate | 585,11 |
| Zinsen Jahr 1 (Summe) | 3.542,98 |
| Tilgung Jahr 1 (Summe) | 3.478,36 |
| Restschuld Ende Jahr 1 | 96.521,64 |
| Effektiver Jahreszins (1+i/12)^12−1 | 3,6600 % |

### 10.8 Python-Skript (Referenzimplementierung)

Reines Python 3 ohne Zusatzpakete. Aufruf `python3 vofi_ref.py` erzeugt alle Tabellen dieses Abschnitts als
Markdown. Für die R-Tests empfiehlt es sich, die ungerundeten Werte über eine zusätzliche CSV-Ausgabe zu exportieren
oder in R mit identischen Eingaben nachzurechnen und gegen die Tabellenwerte (Toleranz 0,005) zu prüfen.

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VoFi-Referenzrechner (Testorakel fuer die R-Engine)
Memo docs/recherche/01_vofi_methodik.md, Stand 2026-10-25.
Reines Python 3 (keine Zusatzpakete). Aufruf: python3 vofi_ref.py
Konventionen: siehe Abschnitt 10.1 des Memos (K1-K14).
"""
INF = float("inf")
EPS = 1e-9


def per(x, T):
    """Skalar oder Liste -> Liste der Laenge T+1 (Index t = 0..T)."""
    if isinstance(x, (int, float)):
        return [float(x)] * (T + 1)
    assert len(x) == T + 1, "Laenge muss T+1 sein"
    return [float(v) for v in x]


class Loan:
    """Darlehen als Zustandsautomat.
    kind      : 'annuity' | 'installment' | 'bullet'
    disb      : {t: Nennbetrag} Auszahlungen (Teilvalutierung moeglich)
    rate      : Periodenzinssatz (Skalar oder Liste T+1; Index t = Zins der Periode t auf Stand t-1)
    term      : Laufzeit in Perioden ab erster Periode nach letzter Auszahlung (inkl. tilgungsfreier
                Perioden); None = bis zur vollstaendigen Tilgung (nur annuity/init_tilg)
    grace     : tilgungsfreie Anlaufperioden
    init_tilg : anfaenglicher Tilgungssatz je Periode (Annuitaet = Nennbetrag*(Zins+init_tilg))
    payout    : Auszahlungskurs (1.0 = 100 %)
    tz, tz_t  : Tilgungszuschuss (Betrag) und Periode der Gutschrift (nach planmaessiger Zahlung)
    tz_effect : 'shorten_term' (Rate bleibt, Laufzeit verkuerzt) | 'reduce_installment'
    commit_fee, fee_from : Bereitstellungsprovision je Periode auf nicht abgerufenen Betrag ab Periode fee_from
    """

    def __init__(self, name, kind, disb, rate, term=None, grace=0, init_tilg=None,
                 payout=1.0, tz=0.0, tz_t=None, tz_effect="shorten_term",
                 commit_fee=0.0, fee_from=10**9):
        self.name, self.kind, self.disb = name, kind, dict(disb)
        self.rate_in, self.term, self.grace = rate, term, grace
        self.init_tilg, self.payout = init_tilg, payout
        self.tz, self.tz_t, self.tz_effect = tz, tz_t, tz_effect
        self.commit_fee, self.fee_from = commit_fee, fee_from
        self.commitment = sum(self.disb.values())
        self.first = max(self.disb) + 1               # erste Periode nach letzter Auszahlung
        self.rep_start = self.first + grace            # erste Tilgungsperiode
        self.mat = None if term is None else self.first + term - 1  # Faelligkeit

    def reset(self, T):
        self.rate = per(self.rate_in, T)
        self.B, self.drawn, self.A, self.R = 0.0, 0.0, None, None

    def step(self, t):
        """Gibt (Auszahlung, Zins, Provision, Tilgung, TZ) der Periode t zurueck."""
        B0 = self.B
        r = self.rate[t]
        zins = r * B0 if t > 0 else 0.0
        fee = 0.0
        if t > 0 and t >= self.fee_from:
            fee = self.commit_fee * (self.commitment - self.drawn)
        tilg = 0.0
        if t >= self.rep_start and B0 > EPS:
            if self.kind == "annuity":
                if self.A is None:
                    basis = self.commitment if self.tz_effect == "shorten_term" else B0
                    if self.init_tilg is not None:
                        self.A = basis * (r + self.init_tilg)
                    else:
                        n = self.mat - self.rep_start + 1
                        self.A = basis * r / (1 - (1 + r) ** (-n)) if r != 0 else basis / n
                tilg = min(self.A - zins, B0)
            elif self.kind == "installment":
                if self.R is None:
                    basis = self.commitment if self.tz_effect == "shorten_term" else B0
                    self.R = basis / (self.mat - self.rep_start + 1)
                tilg = min(self.R, B0)
            if self.mat is not None and t == self.mat:
                tilg = B0                                  # Schlusszahlung / endfaellig
        d = self.disb.get(t, 0.0)
        self.drawn += d
        self.B = B0 - tilg + d
        tz = 0.0
        if self.tz_t is not None and t == self.tz_t and self.tz > 0:
            tz = min(self.tz, self.B)
            self.B -= tz
            if self.tz_effect == "reduce_installment" and t >= self.rep_start and self.B > EPS:
                n_rem = self.mat - t
                r1 = self.rate[min(t + 1, len(self.rate) - 1)]
                if self.kind == "annuity":
                    self.A = self.B * r1 / (1 - (1 + r1) ** (-n_rem))
                elif self.kind == "installment":
                    self.R = self.B / n_rem
        return d * self.payout, zins, fee, tilg, tz


def vofi(T, z, loans=(), einlagen=0.0, entnahmen=0.0, zuschuesse=0.0, steuern=0.0,
         h=0.0, s=0.0, kk_limit=INF, policy="unlimited", sonder=()):
    """Rechnet einen VoFi. h, s = Haben-/Sollzins (KK) je Periode (Skalar oder Liste T+1).
    policy bei Ueberschreiten von kk_limit: 'equity_call' (Nachschuss als Einlage) | 'stop'.
    sonder: Namen der Darlehen, die aus Ueberschuessen (nach KK-Tilgung) sondergetilgt werden
            duerfen (Reihenfolge: hoechster Periodenzins zuerst, nur wenn Zins > Habenzins)."""
    z, einl, entn = per(z, T), per(einlagen, T), per(entnahmen, T)
    zus, st, h, s = per(zuschuesse, T), per(steuern, T), per(h, T), per(s, T)
    for L in loans:
        L.reset(T)
    R = {k: [0.0] * (T + 1) for k in
         ["z", "einl", "nachschuss", "entn", "zus", "steuern", "kk_auf", "kk_tilg", "kk_zins",
          "anlage", "aufl", "hz", "saldo", "G", "KK", "BS", "S_vor"]}
    for L in loans:
        for k in ["auf", "zins", "fee", "tilg", "st", "tz", "B"]:
            R[L.name + "_" + k] = [0.0] * (T + 1)
    G0 = KK0 = 0.0
    for t in range(T + 1):
        flows = z[t] + einl[t] - entn[t] + zus[t] - st[t]
        debt = 0.0
        for L in loans:
            auf, zins, fee, tilg, tz = L.step(t)
            R[L.name + "_auf"][t] = auf
            R[L.name + "_zins"][t] = -zins
            R[L.name + "_fee"][t] = -fee
            R[L.name + "_tilg"][t] = -tilg
            R[L.name + "_tz"][t] = tz
            R[L.name + "_B"][t] = L.B
            flows += auf - zins - fee - tilg
            debt += L.B
        hz = h[t] * G0 if t > 0 else 0.0
        kz = s[t] * KK0 if t > 0 else 0.0
        S = flows + hz - kz
        R["S_vor"][t] = S
        kk_auf = kk_tilg = anlage = aufl = nach = 0.0
        if S >= 0:                       # Ueberschuss: 1. KK tilgen, 2. Sondertilgung, 3. anlegen
            kk_tilg = min(S, KK0)
            rest = S - kk_tilg
            for L in sorted([L for L in loans if L.name in sonder], key=lambda L: -L.rate[t]):
                if rest <= EPS or t == 0 or L.rate[t] <= h[t]:
                    continue
                st_amt = min(rest, L.B)
                L.B -= st_amt
                rest -= st_amt
                debt -= st_amt
                R[L.name + "_st"][t] = -st_amt
                R[L.name + "_B"][t] = L.B
            anlage = rest
        else:                            # Defizit: 1. Guthaben aufloesen, 2. KK bis Limit, 3. Policy
            need = -S
            aufl = min(need, G0)
            need -= aufl
            kk_auf = min(need, max(kk_limit - KK0, 0.0))
            need -= kk_auf
            if need > EPS:
                if policy == "equity_call":
                    nach = need
                else:
                    raise RuntimeError("Liquiditaetsengpass in Periode %d" % t)
        G = G0 + anlage - aufl
        KK = KK0 + kk_auf - kk_tilg
        R["z"][t], R["einl"][t], R["nachschuss"][t] = z[t], einl[t], nach
        R["entn"][t], R["zus"][t], R["steuern"][t] = -entn[t], zus[t], -st[t]
        R["kk_auf"][t], R["kk_tilg"][t], R["kk_zins"][t] = kk_auf, -kk_tilg, -kz
        R["anlage"][t], R["aufl"][t], R["hz"][t] = -anlage, aufl, hz
        R["G"][t], R["KK"][t], R["BS"][t] = G, KK, G - KK - debt
        st_sum = sum(R[L.name + "_st"][t] for L in loans)
        R["saldo"][t] = flows + st_sum + hz - kz + nach + kk_auf - kk_tilg - anlage + aufl
        G0, KK0 = G, KK
    R["_T"], R["_einl_tot"], R["_entn"] = T, [e + n for e, n in zip(einl, R["nachschuss"])], entn
    R["_h"], R["_s"] = h, s
    return R


# ---------- Kennzahlen ----------
def bisect(f, lo, hi, tol=1e-12, it=300):
    flo = f(lo)
    for _ in range(it):
        mid = 0.5 * (lo + hi)
        fm = f(mid)
        if (fm > 0) == (flo > 0):
            lo, flo = mid, fm
        else:
            hi = mid
        if hi - lo < tol:
            break
    return 0.5 * (lo + hi)


def npv(cf, i, tau=None):
    tau = tau or list(range(len(cf)))
    return sum(c / (1 + i) ** u for c, u in zip(cf, tau))


def irr(cf, tau=None, lo=-0.99, hi=1.0):
    f = lambda r: npv(cf, r, tau)
    if f(lo) * f(hi) > 0:
        return None
    return bisect(f, lo, hi)


def kpis(res, tau, restwert=0.0, noi=None, value=None, kd_loans=None):
    """tau: Zeitpunkte in Jahren (Liste T+1). restwert: im z_T enthaltener Restwert."""
    T = res["_T"]
    h = res["_h"]
    einl, entn = res["_einl_tot"], res["_entn"]
    EW = res["BS"][T]
    # Unterlassungsalternative: gleiche Einlagen/Entnahmen, keine Investition, keine Kredite
    U = vofi(T, 0.0, (), einlagen=einl, entnahmen=entn, h=h, s=res["_s"])
    EW_U = U["BS"][T]
    EK0 = einl[0]
    Ty = tau[T] - tau[0]
    out = {"EW": EW, "EW_U": EW_U, "dEW": EW - EW_U, "EK0": EK0}
    out["rEK_klass"] = (EW / EK0) ** (1 / Ty) - 1 if EK0 > 0 and EW > 0 and sum(einl[1:]) == 0 and sum(entn) == 0 else None
    # modifizierte VoFi-EK-Rendite (R3): Entnahmen mit h aufgezinst, Einlagen mit h abgezinst
    acc = [1.0] * (T + 1)                       # Aufzinsfaktor 0 -> t mit Periodenhabenzins
    for t in range(1, T + 1):
        acc[t] = acc[t - 1] * (1 + h[t])
    num = EW + sum(entn[t] * acc[T] / acc[t] for t in range(T + 1))
    den = sum(einl[t] / acc[t] for t in range(T + 1))
    out["rEK_mod"] = (num / den) ** (1 / Ty) - 1 if den > EPS and num > 0 else None
    # Equity-IRR (R2)
    cf = [-einl[t] + entn[t] for t in range(T + 1)]
    cf[T] += EW
    out["rEK_irr"] = irr(cf, tau) if den > EPS else None
    # Amortisation (dauerhaft BS_t >= BS^U_t)
    def amort(bs):
        ta = None
        for t in range(T, -1, -1):
            if bs[t] >= U["BS"][t] - 1e-9:
                ta = tau[t]
            else:
                break
        return ta
    out["t_amort"] = amort(res["BS"])
    bs_ohne = res["BS"][:]
    bs_ohne[T] -= restwert
    out["t_amort_ohneRW"] = amort(bs_ohne)
    out["BS_U"] = U["BS"]
    out["minLiq"] = min(g - k for g, k in zip(res["G"], res["KK"]))
    out["maxKK"] = max(res["KK"])
    out["sum_nachschuss"] = sum(res["nachschuss"])
    if noi is not None and kd_loans is not None:
        dscr, ltv = [None], [None]
        for t in range(1, T + 1):
            kd = sum(-(res[n + "_zins"][t] + res[n + "_tilg"][t]) for n in kd_loans)
            dscr.append(noi[t] / kd if kd > EPS else None)
        out["DSCR"] = dscr
    if value is not None and kd_loans is not None:
        out["LTV"] = [(sum(res[n + "_B"][t] for n in kd_loans) + res["KK"][t]) / value[t]
                      for t in range(T + 1)]
    return out


def entnahme_aequivalent(run, EW_U, T):
    """Konstante Zusatzentnahme E (t=1..T), so dass EW(E) = EW_U. run(E) -> Ergebnis-Dict."""
    f = lambda E: run(E)["BS"][T] - EW_U
    lo, hi = -1e7, 1e7
    return bisect(f, lo, hi, tol=1e-10)


def check(res, loans):
    """Invarianten: (1) Finanzierungssaldo = 0 je Periode;
    (2) Vermoegensfortschreibung: BS_t - BS_{t-1} = z + Einlagen + Nachschuss - Entnahmen + Zuschuesse
        - Steuern - Sollzinsen - Provisionen - Disagio + Habenzinsen + Tilgungszuschuss."""
    T = res["_T"]
    e1 = max(abs(v) for v in res["saldo"])
    e2 = 0.0
    for t in range(T + 1):
        d = res["BS"][t] - (res["BS"][t - 1] if t > 0 else 0.0)
        flow = (res["z"][t] + res["einl"][t] + res["nachschuss"][t] + res["entn"][t] + res["zus"][t]
                + res["steuern"][t] + res["kk_zins"][t] + res["hz"][t])
        for L in loans:
            nominal = L.disb.get(t, 0.0)
            flow += (res[L.name + "_zins"][t] + res[L.name + "_fee"][t] + res[L.name + "_tz"][t]
                     + (res[L.name + "_auf"][t] - nominal))
        e2 = max(e2, abs(d - flow))
    return e1, e2


def unlevered(T, z, h, s):
    """VoFi ohne Fremdkapital: EK = Investitionsauszahlung in t=0 (financing-neutrale Projektsicht)."""
    I0 = -z[0]
    r = vofi(T, z, (), einlagen=[I0] + [0.0] * T, h=h, s=s)
    EW = r["BS"][T]
    return EW, ((EW / I0) ** (1.0 / T) - 1 if EW > 0 else None)


# ---------- Ausgabe ----------
def fmt(x):
    if x is None:
        return "n. d."
    if abs(x) < 5e-10:
        return "–"
    s = "{:,.2f}".format(x)
    return s.replace(",", "X").replace(".", ",").replace("X", ".")


def pct(x, d=4):
    return "n. d." if x is None else ("{:." + str(d) + "f} %").format(100 * x).replace(".", ",")


def table(res, loans, extra_rows=(), header="t", tau_labels=None):
    T = res["_T"]
    cols = tau_labels or [str(t) for t in range(T + 1)]
    lines = ["| Position | " + " | ".join(cols) + " |",
             "|---|" + "---:|" * (T + 1)]
    def row(label, key, show_if_nonzero=False):
        vals = res[key]
        if show_if_nonzero and all(abs(v) < 5e-10 for v in vals):
            return
        lines.append("| " + label + " | " + " | ".join(fmt(v) for v in vals) + " |")
    row("Zahlungsfolge z_t", "z")
    for lab, key in extra_rows:
        row(lab, key)
    row("Zuschüsse (zahlungswirksam)", "zus", True)
    row("EK: Einlage", "einl")
    row("EK: Nachschuss (endogen)", "nachschuss", True)
    row("EK: Entnahme", "entn", True)
    for L in loans:
        row(L.name + ": Aufnahme", L.name + "_auf")
        row(L.name + ": Tilgung", L.name + "_tilg")
        row(L.name + ": Sondertilgung", L.name + "_st", True)
        row(L.name + ": Sollzinsen", L.name + "_zins")
        row(L.name + ": Bereitstellungsprov.", L.name + "_fee", True)
    row("Kontokorrent: Aufnahme", "kk_auf")
    row("Kontokorrent: Tilgung", "kk_tilg")
    row("Kontokorrent: Sollzinsen", "kk_zins")
    row("Geldanlage: Anlage", "anlage")
    row("Geldanlage: Auflösung", "aufl")
    row("Geldanlage: Habenzinsen", "hz")
    row("Steuern (Slot, v1 = 0)", "steuern")
    row("**Finanzierungssaldo**", "saldo")
    for L in loans:
        row(L.name + ": Tilgungszuschuss (zahlungsunwirksam)", L.name + "_tz", True)
        row("Bestand " + L.name, L.name + "_B")
    row("Bestand Kontokorrent", "KK")
    row("Bestand Guthaben", "G")
    row("**Bestandssaldo**", "BS")
    return "\n".join(lines)


def show_kpis(k, title):
    print("\n**Kennzahlen " + title + "**\n")
    print("| Kennzahl | Wert |\n|---|---:|")
    print("| VoFi-Endwert EW | " + fmt(k["EW"]) + " |")
    print("| Endwert Unterlassungsalternative EW_U | " + fmt(k["EW_U"]) + " |")
    print("| Endwertdifferenz ΔEW = EW − EW_U | " + fmt(k["dEW"]) + " |")
    print("| VoFi-EK-Rentabilität klassisch (EW/EK0)^(1/T)−1 | " + pct(k["rEK_klass"]) + " |")
    print("| modifizierte VoFi-EK-Rendite (R3) | " + pct(k["rEK_mod"]) + " |")
    print("| Equity-IRR der EK-Zahlungen (R2) | " + pct(k["rEK_irr"]) + " |")
    print("| VoFi-Amortisationszeitpunkt (mit Restwert) | " + ("keine" if k["t_amort"] is None else ("%g" % k["t_amort"]).replace(".", ",")) + " |")
    print("| VoFi-Amortisationszeitpunkt (ohne Restwert) | " + ("keine im Horizont" if k["t_amort_ohneRW"] is None else ("%g" % k["t_amort_ohneRW"]).replace(".", ",")) + " |")
    print("| min. Nettoliquidität min(G_t − KK_t) | " + fmt(k["minLiq"]) + " |")
    print("| max. Kontokorrentstand | " + fmt(k["maxKK"]) + " |")
    if k["sum_nachschuss"] > 0:
        print("| Summe endogene Nachschüsse | " + fmt(k["sum_nachschuss"]) + " |")


if __name__ == "__main__":
    # ===================== Beispiel (a) =====================
    print("## Beispiel (a)\n")
    T = 5
    RW_a = 40000.0
    z_a = [-100000, 6000, 10000, 30000, 8000, 30000 + RW_a]
    mk_a = lambda: [Loan("Annuitätendarlehen", "annuity", {0: 40000}, 0.06, term=5),
                    Loan("Endfälliges Darlehen", "bullet", {0: 30000}, 0.05, term=5)]
    La = mk_a()
    ra = vofi(T, z_a, La, einlagen=[30000, 0, 0, 0, 0, 0], h=0.03, s=0.10)
    print(table(ra, La))
    tau = list(range(T + 1))
    ka = kpis(ra, tau, restwert=RW_a)
    show_kpis(ka, "(a)")
    run = lambda E: vofi(T, z_a, mk_a(), einlagen=[30000, 0, 0, 0, 0, 0],
                         entnahmen=[0] + [E] * T, h=0.03, s=0.10)
    Ea = entnahme_aequivalent(run, ka["EW_U"], T)
    print("| Entnahme-Äquivalent (VoFi-Annuität, exakt) | " + fmt(Ea) + " |")
    print("| Näherung ΔEW·h/((1+h)^T−1) | " + fmt(ka["dEW"] * 0.03 / (1.03 ** 5 - 1)) + " |")
    print("| Kapitalwert der Zahlungsfolge bei 3 % | " + fmt(npv(z_a, 0.03)) + " |")
    print("| Kapitalwert der Zahlungsfolge bei 10 % | " + fmt(npv(z_a, 0.10)) + " |")
    print("| Interner Zinsfuß der Zahlungsfolge | " + pct(irr(z_a)) + " |")
    print("| Bestandssaldo Unterlassungsalternative je t | " + "; ".join(fmt(v) for v in ka["BS_U"]) + " |")
    EWu_a, rGK_a = unlevered(T, z_a, 0.03, 0.10)
    print("| EW eigenfinanziert (EK = 100.000, keine Kredite) | " + fmt(EWu_a) + " |")
    print("| VoFi-Gesamtkapitalrendite (eigenfinanziert) | " + pct(rGK_a) + " |")
    re = run(Ea)
    print("\nKontrolle: EW bei Entnahme E* =", fmt(re["BS"][T]), "(soll = EW_U)")
    print("\nKontrolle: max|Finanzierungssaldo| = %.1e; max. Abweichung Vermögensfortschreibung = %.1e" % check(ra, La))

    # ----- (a3) Variante: Sondertilgung aus Ueberschuessen (Annuitaetendarlehen) -----
    print("\n### (a3) Variante mit Sondertilgungsregel\n")
    La3 = mk_a()
    ra3 = vofi(T, z_a, La3, einlagen=[30000, 0, 0, 0, 0, 0], h=0.03, s=0.10,
               sonder=("Annuitätendarlehen",))
    print(table(ra3, La3))
    ka3 = kpis(ra3, tau, restwert=RW_a)
    show_kpis(ka3, "(a3)")
    print("\nKontrolle: max|Finanzierungssaldo| = %.1e; max. Abweichung Vermögensfortschreibung = %.1e" % check(ra3, La3))

    # ===================== Beispiel (d): vollkommener Kapitalmarkt =====================
    print("\n## Beispiel (d) Konsistenztest vollkommener Kapitalmarkt (alle Zinssätze 5 %)\n")
    Ld = [Loan("Annuitätendarlehen", "annuity", {0: 40000}, 0.05, term=5),
          Loan("Endfälliges Darlehen", "bullet", {0: 30000}, 0.05, term=5)]
    rd = vofi(T, z_a, Ld, einlagen=[30000, 0, 0, 0, 0, 0], h=0.05, s=0.05)
    kd = kpis(rd, tau, restwert=RW_a)
    print("| Größe | Wert |\n|---|---:|")
    print("| EW | " + fmt(kd["EW"]) + " |")
    print("| EW_U = 30.000·1,05^5 | " + fmt(kd["EW_U"]) + " |")
    print("| ΔEW | " + fmt(kd["dEW"]) + " |")
    print("| KW(5 %)·1,05^5 | " + fmt(npv(z_a, 0.05) * 1.05 ** 5) + " |")
    print("| KW(5 %) | " + fmt(npv(z_a, 0.05)) + " |")
    print("| Differenz (soll 0) | %.3e |" % (kd["dEW"] - npv(z_a, 0.05) * 1.05 ** 5))
    print("| r_EK klassisch | " + pct(kd["rEK_klass"]) + " |")
    print("\nKontrolle: max|Finanzierungssaldo| = %.1e; max. Abweichung Vermögensfortschreibung = %.1e" % check(rd, Ld))

    # ===================== Beispiel (b) =====================
    print("\n## Beispiel (b)\n")
    T = 10
    RW_b = 60000.0
    z_b = [-200000.0] + [14000.0 * 1.02 ** (t - 1) for t in range(1, T + 1)]
    z_b[T] += RW_b
    def mk_b(effect):
        return [Loan("Förderdarlehen", "installment", {0: 150000}, 0.02, term=10, grace=2,
                     tz=22500.0, tz_t=1, tz_effect=effect)]
    for effect, lab in [("shorten_term", "(b1) Tilgungszuschuss verkürzt Laufzeit"),
                        ("reduce_installment", "(b2) Tilgungszuschuss senkt Tilgungsrate")]:
        Lb = mk_b(effect)
        rb = vofi(T, z_b, Lb, einlagen=[50000] + [0] * T, h=0.02, s=0.08)
        print("\n### " + lab + "\n")
        print(table(rb, Lb))
        noi_b = [0.0] + [14000.0 * 1.02 ** (t - 1) for t in range(1, T + 1)]
        kb = kpis(rb, list(range(T + 1)), restwert=RW_b, noi=noi_b, kd_loans=["Förderdarlehen"])
        show_kpis(kb, lab)
        runb = lambda E, effect=effect: vofi(T, z_b, mk_b(effect), einlagen=[50000] + [0] * T,
                                             entnahmen=[0] + [E] * T, h=0.02, s=0.08)
        print("| Entnahme-Äquivalent (exakt) | " + fmt(entnahme_aequivalent(runb, kb["EW_U"], T)) + " |")
        print("| DSCR_t (t=1..10) | " + "; ".join(fmt(v) if v is not None else "n. d." for v in kb["DSCR"][1:]) + " |")
        print("| Kapitalwert z bei 2 % | " + fmt(npv(z_b, 0.02)) + " |")
        print("| IZF z | " + pct(irr(z_b)) + " |")
        print("\nKontrolle: max|Finanzierungssaldo| = %.1e; max. Abweichung Vermögensfortschreibung = %.1e" % check(rb, Lb))

    # ===================== Beispiel (c) =====================
    print("\n## Beispiel (c)\n")
    T = 10
    V0, g, sell = 280000.0, 0.02, 0.03
    V = [V0 * (1 + g) ** t for t in range(T + 1)]
    RW_c = V[T] * (1 - sell)
    noi_c = [0.0] + [12000.0 * 1.02 ** (t - 1) for t in range(1, T + 1)]
    z_c = [-300000.0] + noi_c[1:]
    z_c[T] += RW_c
    mk_c = lambda: [Loan("Annuitätendarlehen", "annuity", {0: 300000}, 0.038, term=None, init_tilg=0.02)]
    Lc = mk_c()
    rc = vofi(T, z_c, Lc, einlagen=0.0, h=0.025, s=0.09)
    print("### (c1) Defizite über Kontokorrent (Limit unbegrenzt)\n")
    print(table(rc, Lc))
    kc = kpis(rc, list(range(T + 1)), restwert=RW_c, noi=noi_c, value=V, kd_loans=["Annuitätendarlehen"])
    show_kpis(kc, "(c1)")
    print("| DSCR_t | " + "; ".join(fmt(v) for v in kc["DSCR"][1:]) + " |")
    print("| LTV_t (inkl. KK) | " + "; ".join(pct(v, 2) for v in kc["LTV"]) + " |")
    print("| Restwert netto (V_T·0,97) | " + fmt(RW_c) + " |")
    runc = lambda E: vofi(T, z_c, mk_c(), einlagen=0.0, entnahmen=[0] + [E] * T, h=0.025, s=0.09)
    print("| Entnahme-Äquivalent (exakt) | " + fmt(entnahme_aequivalent(runc, kc["EW_U"], T)) + " |")
    # Break-even NOI_1 (EW = EW_U = 0)
    def ew_noi(n1):
        noi = [0.0] + [n1 * 1.02 ** (t - 1) for t in range(1, T + 1)]
        zz = [-300000.0] + noi[1:]
        zz[T] += RW_c
        return vofi(T, zz, mk_c(), einlagen=0.0, h=0.025, s=0.09)["BS"][T]
    be = bisect(lambda n1: ew_noi(n1), 0.0, 50000.0)
    print("| Break-even-NOI_1 (ΔEW = 0) | " + fmt(be) + " |")
    print("| Liquiditäts-Break-even-NOI_1 (DSCR_1 = 1) | " + fmt(300000 * 0.058) + " |")
    print("| Projekt-IZF der Zahlungsfolge | " + pct(irr(z_c)) + " |")
    print("| EW / Investitionsvolumen | " + pct(kc["EW"] / 300000, 2) + " |")
    EWu_c, rGK_c = unlevered(T, z_c, 0.025, 0.09)
    print("| EW eigenfinanziert (EK = 300.000) | " + fmt(EWu_c) + " |")
    print("| VoFi-Gesamtkapitalrendite (eigenfinanziert) | " + pct(rGK_c) + " |")
    print("\nKontrolle: max|Finanzierungssaldo| = %.1e; max. Abweichung Vermögensfortschreibung = %.1e" % check(rc, Lc))

    print("\n### (c2) Defizite durch Nachschuss (KK-Limit 0, policy equity_call)\n")
    Lc2 = mk_c()
    rc2 = vofi(T, z_c, Lc2, einlagen=0.0, h=0.025, s=0.09, kk_limit=0.0, policy="equity_call")
    print(table(rc2, Lc2))
    kc2 = kpis(rc2, list(range(T + 1)), restwert=RW_c, noi=noi_c, value=V, kd_loans=["Annuitätendarlehen"])
    show_kpis(kc2, "(c2)")
    print("| Barwert der Nachschüsse bei h | " + fmt(sum(rc2["nachschuss"][t] / 1.025 ** t for t in range(T + 1))) + " |")
    print("\nKontrolle: max|Finanzierungssaldo| = %.1e; max. Abweichung Vermögensfortschreibung = %.1e" % check(rc2, Lc2))

    # ===================== Beispiel (e): nicht-aequidistantes Raster =====================
    print("\n## Beispiel (e) Bauphase quartalsweise, Betriebsphase jaehrlich\n")
    dt = [0.0, .25, .25, .25, .25, 1.0, 1.0, 1.0]
    tau_e = [0.0]
    for d in dt[1:]:
        tau_e.append(tau_e[-1] + d)
    T = 7
    he = [0.0] + [(1.025) ** d - 1 for d in dt[1:]]
    se = [0.0] + [(1.09) ** d - 1 for d in dt[1:]]
    rate_e = [0.0] + [0.036 * d for d in dt[1:]]
    RW_e = 520000.0
    z_e = [-200000.0, -100000.0, -100000.0, -100000.0, 0.0, 30000.0, 30600.0, 31212.0 + RW_e]
    Le = [Loan("Baudarlehen", "annuity", {0: 100000, 1: 100000, 2: 100000, 3: 100000}, rate_e,
               term=None, grace=1, init_tilg=0.02, commit_fee=0.0075, fee_from=2)]
    re_ = vofi(T, z_e, Le, einlagen=[100000.0] + [0.0] * T, h=he, s=se)
    labels = ["0", "0,25", "0,5", "0,75", "1", "2", "3", "4"]
    print(table(re_, Le, tau_labels=labels))
    ke = kpis(re_, tau_e, restwert=RW_e)
    show_kpis(ke, "(e)")
    print("\nPeriodenzinssätze Haben (t=1..7):", "; ".join("%.10f" % x for x in he[1:]))
    print("\nPeriodenzinssätze KK (t=1..7):", "; ".join("%.10f" % x for x in se[1:]))
    print("\nKontrolle: max|Finanzierungssaldo| = %.1e; max. Abweichung Vermögensfortschreibung = %.1e" % check(re_, Le))

    # ===================== Test (f): Monatsannuitaet auf Jahresraster =====================
    print("\n## Test (f) Monatsannuitaet, aggregiert auf Jahresperiode\n")
    K, inom, n = 100000.0, 0.036, 240
    im = inom / 12
    A = K * im / (1 - (1 + im) ** (-n))
    B, zs, ts = K, 0.0, 0.0
    for m in range(12):
        zi = B * im
        ti = A - zi
        zs += zi
        ts += ti
        B -= ti
    print("| Größe | Wert |\n|---|---:|")
    print("| Monatsrate | " + fmt(A) + " |")
    print("| Zinsen Jahr 1 (Summe) | " + fmt(zs) + " |")
    print("| Tilgung Jahr 1 (Summe) | " + fmt(ts) + " |")
    print("| Restschuld Ende Jahr 1 | " + fmt(B) + " |")
    print("| Effektiver Jahreszins (1+i/12)^12−1 | " + pct((1 + im) ** 12 - 1) + " |")
```

---

## 11. Offene Punkte und Risiken

**Offene Fragen (Klärung mit Auftraggeber bzw. in Phase 2):**

1. Standard-Wiederanlagezins h je Perspektive (Tagesgeld, Bundesanleihe, interner Verrechnungszins) und ob h nach
   Steuern angesetzt werden soll, sobald der Steuer-Slot aktiv ist.
2. Voreinstellung der Engpass-Policy (Nachschuss gegen Überziehungszins) und realistische KK-Limits für Privatpersonen.
3. Standardhorizont (Vorschlag 30 Jahre ab Fertigstellung) und Standardrestwertmethode je Anwendungsfall.
4. Soll die regelbasierte Sondertilgung (Ü3) schon in v1 freigeschaltet werden oder nur geplante Sondertilgungen?
5. Wird die Kostenmiete nach II. BV ausdrücklich benötigt (preisgebundener bzw. geförderter Wohnungsbau) oder genügt die
   dynamische kostendeckende Miete?
6. Mieterperspektive (Warmmietenneutralität) als Zusatzauswertung gewünscht?

**Risiken:**

- Die Ergebnisse reagieren stark auf **Restwert** und **Habenzins**. Ohne Pflichtsensitivitäten (Restwert = 0,
  h-Variation) droht Fehlinterpretation.
- Ausgleichs- und Sondertilgungsregeln sind **Heuristiken**, keine Optimierung der Finanzierung. Sie können eine
  suboptimale Finanzierungspolitik abbilden (Beispiele (a3) und (b1)).
- r_EK ist bei kleinem EK, Nachschüssen oder Verlusten instabil bzw. undefiniert. MC-Auswertungen müssen NA sauber
  behandeln.
- Die Aggregation unterjähriger Zahlungen auf Periodenenden verursacht einen kleinen systematischen Fehler
  (dokumentiert, über das Raster steuerbar).
- Förderkonditionen (Tilgungszuschuss-Mechanik, Bereitstellungsprovision, Programmstatus) können sich kurzfristig
  ändern. Sie müssen strikt parametrisiert bleiben (YAML mit Quelle und Datum).
- Die II.-BV-Werte 2026 stammen aus einer Sekundärquelle (Förderbank-Merkblatt). Die amtliche Bekanntmachung ist
  noch zu prüfen.
- Kündigungsrechte (§ 489 BGB), Vorfälligkeitsentschädigungen und Prolongationsrisiken jenseits des
  Anschlusszinses werden in v1 nicht modelliert.

---

## 12. Quellen

| Quelle | Inhalt | Abruf / Stand |
|---|---|---|
| KfW: Programmseite „Bundesförderung für effiziente Gebäude – Wohngebäude – Kredit (261, 262)“, https://www.kfw.de/inlandsfoerderung/Privatpersonen/Bestehende-Immobilie/F%C3%B6rderprodukte/Bundesf%C3%B6rderung-f%C3%BCr-effiziente-Geb%C3%A4ude-Wohngeb%C3%A4ude-Kredit-(261-262)/ | Tilgungszuschuss („reduziert Ihr Darlehen und verkürzt die Laufzeit“, Gutschrift nach Abschluss), Annuitäten- und endfälliges Darlehen, tilgungsfreie Anlaufjahre (1–2 bei 4–10 J., 1–3 bei 11–20 J., 1–5 bei 21–30 J.), Zinsbindung bis 10 J., Bereitstellungsprovision 0,15 % je Monat ab dem 13. Monat | abgerufen 25.10.2026 (Seite © 2026, Richtlinie verlinkt mit Datum 02.09.2026) |
| Dr. Klein: KfW-Darlehen, https://www.drklein.de/kfw-darlehen.html | Sekundärquelle Tilgungszuschuss: Gutschrift reduziert Restschuld und Laufzeit | abgerufen 25.10.2026 |
| Thüringer Aufbaubank: Merkblatt Erfassungsbogen Objektwirtschaftlichkeit Bezahlbarer Mietwohnungsbau (203), 06.2026, Anlage „Pauschalen nach der Zweiten Berechnungsverordnung ab 01.01.2026“, https://dokumente.aufbaubank.de/862739-TAB_Erfassungsbogen_Objektwirtschaftlichkeitsberechnung.pdf | II. BV-Pauschalen 2026 (Verwaltung 372,46 €/WE, Instandhaltung 11,50 / 14,58 / 18,62 €/m²), VPI +8,37 %, nächste Anpassung 01.01.2029; Struktur einer Objektwirtschaftlichkeitsberechnung (Mietausfallwagnis 2 %) | Stand 06.2026, abgerufen 25.10.2026 |
| II. BV § 20 (Eigenkapitalkosten), § 25 (Abschreibung), https://lxgesetze.de/ii-bv/20, https://lxgesetze.de/ii-bv/25 (amtlich: https://www.gesetze-im-internet.de/bvo_2/, beim Abruf HTTP 503) | 4 % bzw. 6,5 % EK-Verzinsung, 1 % Abschreibung | abgerufen 25.10.2026 |
| KIT-Bibliothekskatalog, https://katalog.bibliothek.kit.edu/bib/286602 | Grob (2006), 5. Aufl., Vahlen, ISBN 9783800632763 | abgerufen 25.10.2026 |
| Universität Münster, miami, https://miami.uni-muenster.de/Record/3da51013-debc-498d-b980-23747e43036f | Grob/Mrzyk (1997): Integration von VOFI und Crystal Ball | abgerufen 25.10.2026 |
| CiNii, https://ci.nii.ac.jp/ncid/BD09567188 | Kruschwitz/Lorenz (2019), 15. Aufl., De Gruyter Oldenbourg, ISBN 9783110587357 | abgerufen 25.10.2026 |
| TU Ilmenau, Diskussionspapier, https://db-thueringen.de/servlets/MCRFileNodeServlet/dbt_derivate_00039896/ilm1-2017200571.pdf | Hinweis, dass der VoFi in klassischen Lehrbüchern oft nur am Rand behandelt wird | abgerufen 25.10.2026 |
| Gesetzesverweise ohne eigenen Abruf: § 489 BGB, § 559a BGB, § 14 PfandBG, BelWertV, ImmoWertV 2021 | nur für Einordnung. Fachliche Prüfung im Rechts- bzw. Parameter-Memo | – |
| Grob (1989), Grob (1993), Götze, Ropeter (1998) | Methodik (Literatur, nicht online eingesehen) | – |

*Alle Zahlenbeispiele in Abschnitt 10 sind stilisierte Testfälle und keine Markt- oder Förderkonditionen.*
