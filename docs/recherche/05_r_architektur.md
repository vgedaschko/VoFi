# Recherche-Memo 05: R-Softwarearchitektur und Engineering

| | |
|---|---|
| **Projekt** | VoFi-Tool (R) für Neubau und energetische Sanierung, Wohnungswirtschaft und Privatpersonen |
| **Thema** | Architekturalternativen, Paketlayout, Eingabeformat, Plugin-Registry, Steuer-Hook, Rechenkern, Ergebnisklassen, Reporting, Tests, Performance, Abhängigkeiten, Arbeitsteilung für parallele Implementierung |
| **Stand** | 25.10.2026 |
| **Status** | Recherche-/Entscheidungsgrundlage für Phase 2 (Konzept und technische Spezifikation) |
| **Ablage** | `docs/recherche/05_r_architektur.md` |
| **Bezug** | Memo 01 (VoFi-Methodik, Rechenkern, Testorakel), Memo 02 (Domänenmodell, Recht, Förderung) |
| **Umgebung der Messungen** | R 4.3.3, Ubuntu 24.04, 4 Kerne, 15 GB RAM; Pakete wie im Projektkontext angegeben |

> **Lesehinweis.** Abschnitt 0 fasst die Entscheidungsvorschläge zusammen. Abschnitt 2 vergleicht drei
> Architekturalternativen mit gemessenen Prototyp-Benchmarks. Die Abschnitte 3 bis 12 spezifizieren die empfohlene
> Variante. Sie decken die zehn Punkte des Auftrags ab und enthalten die Modulkarte und den Plan für die parallele
> Umsetzung durch mehrere Agenten. Bezeichner und Eingabeschlüssel sind englisch (snake_case), alle Texte für Nutzer
> sind deutsch. Die Zeilenschlüssel der VoFi-Tabelle (`equity_in`, `loan_<k>_interest`, `od_draw` …), die
> Ausgleichsrangfolge Ü1–Ü4/D1–D4 und die Invarianten I1–I6 übernimmt dieses Memo unverändert aus Memo 01.
> Die Domänenentitäten und Parameterschlüssel (`project`, `building`, `unit_groups`, `measures`, `funding`, `legal_state` …)
> stammen aus Memo 02. Abgestimmt sind außerdem das Stochastik-Overlay, die Verteilungen und Prozesse, die benannten
> Zufallsströme und die Speicherstrategie aus Memo 04, die Steuerschnittstelle (`tax_category`, Anlagen- und
> Maßnahmenregister, `tax_init`/`tax_step`/`tax_finalize`) aus Memo 06 und die Adaptivitätsanforderungen A-01 bis A-25
> sowie die Referenzszenarien S1–S5 aus Memo 07. Wo die Memos voneinander abweichen, nennt Abschnitt 13 den Punkt.

---

## 0. Kurzfassung und Entscheidungsvorschläge

**Kernaussage.** Empfohlen wird **Variante A**: ein R-Paket `vofi` aus **reinen Funktionen über einfachen Listen mit
S3-Klassen**, einem **über die Simulationen vektorisierten Matrix-Rechenkern** (alle Zeitreihen sind Matrizen
N × (T+1), deterministisch heißt N = 1) und einer **Registry**, in der Zahlungskomponenten, Kreditinstrumente,
Ausgleichsaktionen, Verteilungen, stochastische Prozesse, Kennzahlen und Steuermodule als Funktionen eingetragen sind. Die Engine
kennt keine konkreten Typen. Neue Typen entstehen als neue Datei, ohne dass sich der Kern ändert. Der Prototyp
dieser Architektur rechnet **10.000 Simulationen × 83 Perioden** (12 Monate Bauphase + 70 Betriebsjahre, drei Kredite
als Zustandsautomaten, Ausgleichsketten, Steuer-Slot) in **rund 0,3 s**, einen deterministischen Lauf in **rund 10 ms**.
R6 und eine Tidy-Pipeline sind bei der Monte-Carlo-Simulation um das 100- bis 180-Fache langsamer, wenn sie wie üblich je
Simulation rechnen. Sie bringen außerdem mehr Abhängigkeiten (Tidy) bzw. Referenzsemantik (R6) mit, was bei
Varianten und Sensitivitäten zu Fehlern führt.

| Nr. | Entscheidungsvorschlag | Begründung (Kurz) |
|---|---|---|
| A1 | **Architektur A**: Paket `vofi`, Listen und S3, vektorisierter Matrix-Kern, Funktions-Registry. Long-Format-Data-Frames nur an der Ausgabegrenze (`as.data.frame()`). | Bestwert in fünf von sechs Kriterien (Abschnitt 2.6). Gemessen 0,12 bis 0,36 s je 10.000 Läufe. Minimale Abhängigkeiten. |
| A2 | **Ein kanonisches Szenario-Objekt** (benannte R-Liste, Klasse `vofi_scenario`), in das **YAML** (versionierbar, für Fachentwickler und Git) und **Excel** (für Praktiker) verlustfrei übersetzt werden. Beide Richtungen sind getestet (Round-Trip). | Eine einzige Validierung und Auflösung. Excel speichert Zahlen gebietsschemaunabhängig, YAML bleibt diff-fähig. |
| A3 | **Schichtenmodell für Parameter** mit Deep-Merge: Typ-Defaults < globale Defaults < Perspektiven-Profil < Bibliothekseinträge (`from:`) < Nutzerbibliothek < Szenario < Stochastik-Overlay (Memo 04, nur MC) < Variante < Laufzeit-Overrides. Für jeden Blattwert wird die **Herkunft** gespeichert (Datei, Eintrag, Excel-Zelle). | Adaptivität ohne Kopien. Nachvollziehbarkeit für Controller („woher kommt dieser Zinssatz?“). |
| A4 | **Zwei Eingabeebenen**: Die *Domänenebene* (Gebäude, Wohnungsgruppen, Maßnahmen, Förderung nach Memo 02) wird von **Expandern** in die *Komponentenebene* (typisierte Zahlungskomponenten und Instrumente) übersetzt. Die Engine sieht nur Komponenten. Komponenten lassen sich auch direkt angeben. | Fachlich natürliche Eingabe, generischer Kern, Ausweg für Sonderfälle (`custom_series`). |
| A5 | **Registry mit Arten** (`flow`, `instrument`, `account_action`, `expander`, `distribution`, `process`, `kpi`, `tax`, `rule`). Eingebaute Typen werden beim Laden über die **Namenskonvention `typedef_*`** gefunden, es gibt keine zentrale Liste. | Parallele Entwicklung ohne Merge-Konflikte. Ein Vertragstest prüft jeden registrierten Typ automatisch. |
| A6 | **Kredite sind Zustandsautomaten** (`init`/`step`/`prepay`) in der Periodenschleife (Memo 01, E9). **Ausgleich** über konfigurierbare **Aktionsketten** Ü1–Ü4/D1–D4 inklusive Engpass-Policy (Memo 01, 3.2). | Sondertilgung, Anschlusszins, Tilgungszuschuss und Kontokorrent wirken ohne Sonderfälle zusammen. Die Kosten sind gemessen vernachlässigbar. |
| A7 | **Steuer-Hook nach Memo 06 §7**: S3-Generics `tax_init`/`tax_step`/`tax_finalize`, aufgerufen in jeder Periode vor dem Ausgleich. Das Null-Modul `tax_none` läuft in jedem Lauf (Zeile „Ertragsteuern“ sichtbar mit 0). Jede Zeile trägt ab v1 `section`, `category`, `tax_category` (Vokabular Memo 06 §7.2) und `cash`, Investitionen und Förderung zusätzlich `asset_id`/`measure_id`. Anlagen- und Maßnahmenregister gibt es ab v1. | Das spätere Steuermodul braucht kein Refactoring. Der Slot sieht auch endogene Zinsen (Habenzinsen, KK-Zinsen) und ist nicht zirkulär. `tax_flat` (Memo 06 §6.2) prüft die Schnittstelle als Referenzmodul. |
| A8 | **Zufallszahlen strikt getrennt vom Rechnen**: Ein zentraler Sampler erzeugt Ziehungen je *benanntem Strom* (Memo 04 §4.3) und *RNG-Block* (1.000 Läufe = ein LHS-Replikat) mit abgeleiteten Seeds. Typen ziehen nie selbst. | Gemeinsame Zufallszahlen (CRN) über Varianten. Jeder Lauf ist exakt reproduzierbar, unabhängig von Chunk-Größe und Worker-Zahl. Ein neuer Parameter verschiebt keine anderen Ziehungen (im Prototyp geprüft). |
| A9 | **Ergebnisklassen** `vofi_result`, `vofi_mc_result`, `vofi_comparison`, `vofi_sensitivity` mit `print`, `summary`, `format`, `plot`, `as.data.frame`. Die VoFi-Tabelle im Grob-Layout und transponiert stammt aus einem Ledger (Zeilen-Metadaten + Matrizen). | Eine Datenquelle für Konsole, Excel, HTML und Shiny. |
| A10 | **Alle deutschen Texte in Label-Katalogen** (`inst/labels/de/*.yaml`), nicht im R-Code. | Im Test geprüft: Umlaute im R-Code erzeugen bei `R CMD check` eine WARNING („Portable packages must use only ASCII characters in their R code“). Mit Katalog ergibt `R CMD check` Status OK. roxygen-Doku mit Umlauten ist unproblematisch (`Encoding: UTF-8`). |
| A11 | **Imports minimal: `yaml`, `openxlsx`** (rekursiv 6 Fremdpakete) plus `stats`, `utils`, `tools`. Alles andere (ggplot2, rmarkdown, shiny, future.apply, …) steht in Suggests. | Schlanke Installation und stabile Wartung. LHS, Copula und Wurzelsuche sind in wenigen Zeilen Base R umsetzbar. |
| A12 | **Testpyramide**: Vertragstests je Typ, Orakel (a) bis (f) aus Memo 01, Invarianten I1–I6 für alle Läufe, eine **skalare Referenz-Engine** für Differenztests, metamorphe und statistische MC-Tests sowie Snapshots für deutsche Ausgaben. Abdeckung ≥ 90 % im Kern, ≥ 80 % gesamt. `R CMD check` ohne WARNING/NOTE. | Die Korrektheit des Rechenkerns ist das Hauptrisiko. Vektorisierungsfehler (`max` statt `pmax`) fängt der Invarianz-Test „Lauf i im Batch = Einzellauf i“ ab. |
| A13 | **Reporting v1**: VoFi-Tabelle (Konsole, Excel mit Formel-Finanzierungssaldo), Kennzahlen, ggplot2-Grafiken, HTML- und DOCX-Bericht über rmarkdown, jeweils im Fach- und im Haushaltsmodus (Memo 07). **Shiny erst in v1.1** als Viewer mit Parameter-Reglern. | Hoher Nutzen bei geringem Risiko. Shiny hängt von einer stabilen API ab. |
| A14 | **Parallele Umsetzung**: Phase 0 (seriell) friert Verträge ein, legt Stubs aller exportierten Funktionen an, dazu Testhelfer, Vokabulare, CI und ein lauffähiges End-to-End-Gerüst. Danach arbeiten 6 bis 8 Agenten parallel an disjunkten Dateien (Abschnitt 12). | Konfliktdateien (DESCRIPTION, NAMESPACE, zzz.R, Verträge) gehören nur dem Integrator. |

---

## 1. Anforderungen an die Architektur

| Nr. | Anforderung | Quelle | Architekturfolge |
|---|---|---|---|
| R1 | Maximale Anpassbarkeit: neue Finanzierungsinstrumente, Zahlungsmodule, Förderprogramme, Rechtsstände, später Steuern | Projektkontext, Memo 02 §10 | Registry, Bibliothek mit Gültigkeitsdaten, Expander, Steuer-Hook |
| R2 | Drei Perspektiven (WU, Kleinvermieter, Selbstnutzer), zwei Projektarten (Neubau, Sanierung), Total- und Differenz-VoFi | Memo 01 E6, Memo 02 §1.1, §6 | Perspektiven-Profile als Default-Schicht, Varianten, `vofi_compare()` |
| R3 | Monte Carlo mit 10.000+ Läufen × 50–80 Perioden | Projektkontext, Memo 01 E10 | Matrix-Kern N × (T+1), Schleife nur über t |
| R4 | Nicht äquidistantes Raster (Bauphase monatlich, Betrieb jährlich), Kredite in Vertragsfrequenz | Memo 01 E7, Memo 02 §0 Nr. 4 | Raster als Vektor Δ_t; Instrumente und Regeln dürfen intern feiner rechnen und aggregieren |
| R5 | Vorsteuer-VoFi in v1, Steuer-Slot vorbereitet und auch in der Unterlassungsalternative wirksam | Memo 01 E11 | Steuermodul `none`, Pflicht-Tags, Opportunitätsmodell nutzt dasselbe Modul |
| R6 | Nachvollziehbarkeit für Controller | Projektkontext | Grob-Tabelle, Herkunftsnachweis, Excel-Export mit Annahmenblatt, kurzer Kern |
| R7 | Deutsche Oberfläche, englische Bezeichner | Projektkontext | Label-Katalog, deutsche roxygen-Doku, deutsches Zahlenformat |
| R8 | Reproduzierbarkeit (Seed, Rechtsstand, Bibliotheksstand) | Memo 02 §10 Nr. 5 | Ergebnis enthält aufgelöste Spezifikation, Seed, Version, Bibliotheksstände |
| R9 | Testbarkeit gegen Orakel und Invarianten | Memo 01 E13 | Reine Funktionen, injizierbare Ziehungen, Referenz-Engine |
| R10 | Parallele Implementierung durch mehrere Agenten | Projektkontext | Verträge zuerst, Datei je Typ, keine zentralen Listen |

---

## 2. Architekturalternativen

### 2.1 Alternative A: R-Paket mit Listen/S3 und vektorisiertem Matrix-Kern

**Aufbau.** Ein Szenario ist eine benannte Liste. Der Build übersetzt es in ein `vofi_model`: Zeitraster,
topologisch sortierte Komponenten, Sampler-Plan, Ausgleichsketten und Steuermodul. Jeder Typ ist eine **Funktion**
(bzw. ein kleines Funktionsbündel) in einer Registry (Umgebung `.vofi_registry`). Komponenten liefern benannte Matrizen
N × (T+1) mit Tags. Die Engine summiert die exogenen Zeilen. In der Periodenschleife (t = 0 … T) laufen Kredite als
Zustandsautomaten, danach Zinsen, Steuer-Slot und Ausgleich, jeweils elementweise über Vektoren der Länge N.
Ergebnisse sind S3-Objekte mit generischen Methoden.

- **Stärken:** Werte statt Referenzen (eine Variante ist eine Kopie, keine Aliasing-Fehler). Typen sind einfache,
  isoliert testbare Funktionen. Die Vektorisierung über N gibt dem deterministischen und dem stochastischen Fall
  denselben Codepfad. Es braucht fast keine Abhängigkeiten. Idiomatisch für R-Pakete (roxygen, S3-Generics).
- **Schwächen:** Die Disziplin bei Vektorisierung ist kritisch (`pmax` statt `max`, `drop = FALSE`). Abhilfe sind
  Vertrags- und Invarianztests. Der Speicherbedarf bei vollem Ledger ist hoch (36 Zeilen × 10.000 × 81 × 8 Byte ≈ 233 MB).
  Abhilfe ist die `store`-Strategie (Abschnitt 6.9).

### 2.2 Alternative B: R6-Objektmodell

**Aufbau.** Klassen `Scenario`, `Component` (abstrakt) mit Unterklassen (`RentComponent`, `AnnuityLoan`, `KfwLoan`
erbt von `AnnuityLoan` …), `Account`, `Engine`. Der Zustand liegt in Feldern (`self$balance`), Erweiterung erfolgt durch
Vererbung.

- **Stärken:** Vertraute OOP für Entwickler aus Java/Python. Zustandsautomaten (Kredite, Konten) sind natürlich
  ausdrückbar. Methodenverkettung ist möglich. Für einen Shiny-Editor mit veränderlichem Zustand bequem.
- **Schwächen:** **Referenzsemantik**: `v <- base` kopiert nicht. Varianten, Sensitivitäten und Break-even-Suchen
  erzeugen Hunderte veränderter Kopien und brauchen überall `$clone(deep = TRUE)`, eine typische Fehlerquelle.
  Ein Objekt je Simulation ist sehr langsam: im Benchmark **≈ 4,9 s statt 0,027 s** allein für die Ausgleichsschleife
  (≈ 180-fach). Wird intern doch über N vektorisiert, ist man funktional bei A, nur mit mehr Zeremonie
  (`self$`, `$new()`). Serialisierte R6-Objekte (`saveRDS`) hängen an der Klassendefinition, ältere Ergebnisse
  lassen sich nach Paket-Updates schlechter laden. Für Controller weniger transparent (`str()` zeigt Umgebungen).
  S3-Generics für Ergebnisse braucht man trotzdem.

### 2.3 Alternative C: Tidy-Data-Frame-Pipeline

**Aufbau.** Alle Zahlungen stehen in einem langen Data Frame (`sim`, `period`, `row`, `value`). Komponenten sind
`mutate()`-Schritte, der Ausgleich läuft über `group_by(sim)` mit `purrr::accumulate()`/`reduce()`.

- **Stärken:** Gut lesbare Verben für Aggregation und Auswertung. Direkt an ggplot2 anschließbar. Vertraut für
  Analysten.
- **Schwächen:** Der VoFi-Ausgleich ist eine **sequenzielle Rekursion** (Zinsen auf Vorperiodenbestände). Gruppenweise
  Akkumulation dauert im Benchmark **≈ 2,9 s statt 0,027 s** (≈ 107-fach) allein für den Ausgleich. Speicher: 36 Zeilen
  × 81 Perioden × 10.000 Läufe ≈ 29 Mio. Zeilen im Long-Format (mehrere hundert MB). Rekursiver Abhängigkeitsbaum
  von dplyr allein: 14 Pakete (dazu tidyr, purrr, tibble …). NSE im Paketcode (`.data`, `globalVariables`). API-Wandel
  im Tidyverse (Deprecations) erhöht den Wartungsaufwand. Kredit-Zustandsautomaten mit Sondertilgung lassen sich
  nur umständlich abbilden.

### 2.4 Weitere geprüfte Optionen (verworfen bzw. später)

| Option | Bewertung |
|---|---|
| D: Rcpp/C++-Kern | Schnellste Variante, aber Compiler-Toolchain nötig, für Controller unlesbar, für parallele Agenten schwerer testbar. Nach den Messungen **nicht nötig**. Bleibt als spätere Optimierung *hinter derselben Schnittstelle* möglich (z. B. nur die Ausgleichsschleife). |
| E: data.table als Speicher | Keine Abhängigkeiten, schnell beim Gruppieren. Die Schleife über t bleibt trotzdem nötig, `:=` bringt Referenzsemantik wie bei R6. Kein Mehrwert gegenüber Matrizen im Kern. Optional für große Ausgabetabellen. |
| F: Skalarer Kern + MC als äußere Schleife | Der naheliegende Ansatz („erst deterministisch bauen, dann N-mal aufrufen“) dauert im Benchmark **27,8 s statt 0,25 s** (≈ 110-fach). Ausgeschlossen. |

### 2.5 Prototyp-Benchmarks (gemessen am 25.10.2026)

Drei Prototypen wurden in R 4.3.3 gemessen (`bench::mark`, Median):
(P1) handgeschriebener Matrix-Kern mit 20 Zeilen;
(P2) generischer Registry-Kern mit 36 Zeilen (22 Komponenten, Wertauflösung über `ctx`, Steuer-Hook, `amount: auto`);
(P3) Kern mit **Krediten als Zustandsautomaten in der Schleife**, Ausgleichsaktionsketten (Ü1/Ü4, D1/D2/D4) und
nicht äquidistantem Raster (12 Monatsperioden + Jahresperioden). Der Code von P3 steht in Anhang A.

| Messung | N | Perioden (T+1) | Zeit | Speicher alloziert |
|---|---:|---:|---:|---:|
| P1 Gesamtlauf (Treiber, Komponenten, 2 Kredite, Ausgleich, Kennzahlen) | 10.000 | 41 | 0,25 s | 392 MB |
| P1 Gesamtlauf | 10.000 | 81 | 0,50 s | 772 MB |
| P1 davon Treibersimulation (korrelierte Schocks, AR(1), GBM, Vasicek) | 10.000 | 40 | ≈ 0,10 s | 93–111 MB |
| P1 davon Annuitätendarlehen mit stochastischem Anschlusszins | 10.000 | 41 | 12 ms | 43 MB |
| P1 davon Ausgleichsschleife | 10.000 | 41 | 24 ms | 75 MB |
| P2 deterministisch (36 Zeilen) | 1 | 41 / 81 | 2,3 ms / 4,3 ms | < 2 MB |
| P2 Monte Carlo | 10.000 | 41 | 0,12 s | 375 MB |
| P2 Monte Carlo | 10.000 | 81 | 0,30 s | 735 MB |
| P2 Monte Carlo mit Steuer-Hook (Pauschalsatz) | 10.000 | 41 / 81 | 0,16 s / 0,36 s | 466 / 913 MB |
| P2 ohne Byte-Compiler (`enableJIT(0)`) | 10.000 | 81 | 1,14 s | – |
| **P3 deterministisch** (3 Zustandsautomaten, 12 Monate Bau + 70 J.) | 1 | 83 | **10,5 ms** | 40 KB |
| **P3 Monte Carlo** (12 Monate Bau + 40 J.) | 10.000 | 53 | **0,23 s** | 456 MB |
| **P3 Monte Carlo** (12 Monate Bau + 70 J.) | 10.000 | 83 | **0,30 s** | 719 MB |
| P3 Monte Carlo mit Steuer-Slot | 10.000 | 83 | 0,28 s | 738 MB |
| Skalierung P1 (nur Kennzahlen) | 1 / 100 / 1.000 / 10.000 / 50.000 | 41 | 2,1 ms / 4,4 ms / 32 ms / 0,23 s / 1,17 s | linear |
| Ledger im Speicher (P2, 29 exogene Zeilen, `object.size`) | 10.000 | 81 | – | 179 MiB |
| Kennzahl VoFi-Rendite, vektorisierte Bisektion naiv (`outer`) | 10.000 | 81 | 836 ms | – |
| Kennzahl VoFi-Rendite, Bisektion mit Horner-Schema | 10.000 | 81 | **28 ms** (Abw. zu `uniroot` < 1e-11) | – |
| Quantilbänder (5 Quantile je Periode, eine Zeile) | 10.000 | 81 | 28 ms | – |

**Vergleich nur der Ausgleichsschleife** (N = 10.000, T = 40, identische Eingaben, Ergebnisse bis 1e-8 gleich):

| Architektur | Zeit | Faktor |
|---|---:|---:|
| A: vektorisiert über N, Schleife über t | 0,027 s | 1 |
| Skalare Doppelschleife (byte-kompiliert) | 0,071 s | 2,6 |
| C: dplyr + purrr::reduce je Simulation (gemessen 1.000, hochgerechnet) | ≈ 2,9 s | ≈ 107 |
| B: R6-Objekt je Simulation (gemessen 1.000, hochgerechnet) | ≈ 4,9 s | ≈ 180 |
| F: gesamte Engine je Simulation aufgerufen (gemessen 1.000, hochgerechnet) | ≈ 27,8 s | ≈ 110 (ggü. Gesamtlauf 0,25 s) |

**Lesart.**
1. Der Engpass ist nicht die Schleife über t, sondern alles, was *je Simulation* Funktionsaufrufe erzeugt.
   Die skalare Schleife allein ist dank Byte-Compiler nur 2,6-mal langsamer. Komponentenbau, Sampling und Kennzahlen je
   Lauf machen den Unterschied (Faktor 110).
2. Etwa 35 % der Laufzeit sind Zufallszahlenerzeugung (`rnorm`, `rbeta`, Profil P1). Das lässt sich nicht
   wegoptimieren, nur begrenzen (nur benötigte Treiber ziehen).
3. **Parallelisierung lohnt erst ab etwa 10⁶ Läufen**: 100.000 Läufe dauern sequenziell 2,10 s und mit
   `future::multisession` (4 Worker) 3,35 s, weil der Start der Worker die Rechenzeit übersteigt. Die Ergebnisse waren
   identisch (Seeds je Chunk).
4. Der **Byte-Compiler ist Pflicht**. Paketcode wird standardmäßig kompiliert. `ByteCompile: no` darf nicht gesetzt
   werden.
5. Ein naiver `set.seed(seed); rnorm(n*T)` macht Lauf 1 von N abhängig (P3: Lauf 1 im Batch ≠ Einzellauf).
   Deshalb gibt es Block-Seeds je Schlüssel (Abschnitt 6.3).

### 2.6 Bewertungsmatrix

Skala 1 (schlecht) bis 5 (sehr gut), Gewichte nach Projektzielen.

| Kriterium | Gewicht | A Listen/S3 + Matrix | B R6 | C Tidy-Pipeline |
|---|---:|:---:|:---:|:---:|
| Adaptivität/Erweiterbarkeit (neue Instrumente, Module, Steuermodul) | 25 % | **5**: Registry von Funktionen, Varianten als Daten, Expander | 4: Vererbung, aber Registry für YAML trotzdem nötig, Klonprobleme bei Varianten | 3: neue Zeilen einfach, zustandsbehaftete Instrumente umständlich |
| MC-Performance (10k × 50–80) | 20 % | **5**: 0,12–0,36 s gemessen | 3 (intern vektorisiert) bzw. 1 (Objekt je Lauf) | 1–2 |
| Testbarkeit | 15 % | **5**: reine Funktionen, injizierbare Ziehungen, Vertragstests | 3: Zustand, Mocks, Klonen | 4: rein, aber langsame Tests |
| Lesbarkeit für Controller | 15 % | 4: kurze Funktionen, Grob-Tabelle, Herkunftsnachweis | 3: `self$`, Umgebungen | **4–5**: Pipelines gut lesbar, Rekursion nicht |
| Abhängigkeiten | 10 % | **5**: yaml, openxlsx | 4: + R6 (0 Abh.) | 2: ≈ 20 Pakete |
| Wartbarkeit/parallele Entwicklung | 15 % | **5**: Datei je Typ, keine Hierarchie | 3: Klassenhierarchie koppelt | 3 |
| **Gewichtete Summe** | 100 % | **4,85** | **3,40** | **2,85** |

### 2.7 Empfehlung

**Alternative A**, ergänzt um zwei Elemente aus B und C:
- aus **B** das Denkmodell *Zustandsautomat* für Kredite und Konten, umgesetzt als Funktionsbündel
  (`init`, `step`, `prepay`) über Zustandslisten mit N-Vektoren, ohne R6;
- aus **C** das *Long-Format an der Ausgabegrenze*: `as.data.frame(result)` liefert `row_key × period × sim × value`
  für alle, die mit dplyr/ggplot2 weiterarbeiten wollen.

---

## 3. Paketlayout und Konventionen

### 3.1 Verzeichnisbaum

```text
vofi/
├── DESCRIPTION
├── NAMESPACE                     # generiert (roxygen2), nur Integrator committet
├── NEWS.md                       # deutsch
├── LICENSE / LICENSE.md          # offen (Frage an Auftraggeber)
├── .Rbuildignore  .lintr  .gitignore
├── R/                            # nur ASCII (Texte über Label-Katalog), Module siehe Abschnitt 11
│   ├── vofi-package.R  zzz.R  contracts.R  registry.R  vocab.R  labels.R  conditions.R
│   ├── utils-*.R  time-grid.R  values.R  expr.R
│   ├── scenario-*.R  io-yaml.R  io-excel-*.R  schema.R  validate-*.R
│   ├── expand-*.R  rules-*.R
│   ├── sampling.R  dist-*.R  process-*.R
│   ├── engine-*.R  account-actions.R  kpi-*.R  tax-hook.R  tax-none.R  tax-flat.R  tax-selfuse.R  opportunity.R
│   ├── type-flow-*.R  type-inst-*.R
│   ├── mc.R  compare.R  sensitivity.R  solve.R
│   ├── methods-*.R  report-*.R  app.R
├── inst/
│   ├── extdata/
│   │   ├── defaults/global.yaml
│   │   ├── profiles/{wu_kommunal,wu_genossenschaft,wu_privat,kleinvermieter,selbstnutzer}.yaml
│   │   ├── library/                       # Parameterbibliothek, ein Eintrag je Datei
│   │   │   ├── funding/  kfw_261_eh55.yaml  kfw_458_heizung_privat.yaml  …
│   │   │   ├── legal/    mietrecht_2026-10.yaml  co2kostaufg_2026-07.yaml  …
│   │   │   ├── prices/   co2_price_paths_2026.yaml  energy_prices_2026.yaml  interest_rates_2026-10.yaml
│   │   │   ├── costs/    bewirtschaftung_2026.yaml  lifetimes.yaml  …
│   │   │   ├── processes/  mortgage_rate_vasicek_2026.yaml  inflation_ar1_de.yaml  …
│   │   │   └── valuation/ immowertv_anlage2.yaml  …
│   │   └── examples/                      # Beispielszenarien (YAML + daraus erzeugte XLSX)
│   │       ├── s1_wu_sanierung_mfh_1963.yaml … s5_selbstnutzer_neubau_efh.yaml   # Memo 07 S1–S5
│   │       ├── grob_lehrbuch_a.yaml                                           # Memo 01 (a)
│   │       └── *.xlsx
│   ├── labels/de/                         # deutsche Texte, je Modul/Typ eine Datei
│   │   ├── core.yaml  validation.yaml  report.yaml  kpi.yaml  excel.yaml
│   │   └── types/<typname>.yaml
│   ├── vocab/  sections.yaml  categories.yaml  tax_categories.yaml  asset_types.yaml  enums.yaml
│   ├── params/ steuern_DE.yaml                # versionierte Steuerparameter (Memo 06 §7.6)
│   ├── templates/
│   │   ├── vofi_eingabe.xlsx              # aus Registry generiert (data-raw/build_template.R)
│   │   └── report/  vofi_bericht.Rmd  vofi_bericht.css  referenz.docx
│   ├── shiny/vofi/  app.R  R/mod_*.R      # ab v1.1
│   └── schema/vofi-scenario.schema.json   # generiert, für Editor-Autovervollständigung
├── tests/
│   ├── testthat.R
│   └── testthat/
│       ├── helper-contracts.R  helper-fixtures.R  helper-reference-engine.R
│       ├── test-<modul>.R …  test-contract-types.R  test-invariants.R  test-oracles.R
│       ├── test-mc-statistics.R  test-io-roundtrip.R  test-snapshots-*.R
│       ├── fixtures/ oracles/*.yaml *_expected.csv  scenarios/*.yaml  excel/*.xlsx
│       └── _snaps/
├── vignettes/                             # deutsch
│   ├── vofi-einfuehrung.Rmd  vofi-szenarien.Rmd  vofi-methodik.Rmd
│   ├── vofi-wohnungsunternehmen.Rmd  vofi-selbstnutzer-sanierung.Rmd
│   ├── vofi-monte-carlo.Rmd  vofi-erweitern.Rmd
├── data-raw/   build_template.R  build_schema.R  build_examples_xlsx.R   (.Rbuildignore)
├── bench/      bench_engine.R  bench_mc.R                                 (.Rbuildignore)
└── docs/       recherche/ …  entwicklung/vertraege.md  entwicklung/zustaendigkeiten.md
```

### 3.2 DESCRIPTION (Entwurf)

```text
Package: vofi
Type: Package
Title: Vollständiger Finanzplan (VoFi) mit Monte-Carlo-Simulation für Wohngebäude
Version: 0.1.0
Authors@R: person("…", "…", email = "…", role = c("aut", "cre"))
Description: Wirtschaftlichkeitsbewertung von Neubau und energetischer
    Sanierung von Wohngebäuden in Deutschland nach der Methode des
    Vollständigen Finanzplans (Grob) aus Sicht von Wohnungsunternehmen,
    privaten Vermietern und Selbstnutzern. Enthält Szenarien in YAML und
    Excel, eine Parameterbibliothek, Monte-Carlo-Simulation, Varianten-,
    Sensitivitäts- und Break-even-Analysen sowie Berichte.
License: <offen>
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
    bslib, DT, future (>= 1.33.0), future.apply (>= 1.11.0),
    ggplot2 (>= 3.4.0), jsonlite, knitr, rmarkdown, shiny (>= 1.8.0),
    testthat (>= 3.0.0), vdiffr, withr
VignetteBuilder: knitr
Config/testthat/edition: 3
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.3.1
```

Hinweise: `Language: de` steuert u. a. die Rechtschreibprüfung der Dokumentation. Die Mindestversionen entsprechen der
Installationsbasis (Ubuntu-apt-Pakete). Auf CRAN sind die Pakete inzwischen neuer (z. B. ggplot2 4.0.3, shiny
1.14.0, testthat 3.3.2, openxlsx 4.2.9). Die CI sollte beide Stände testen. Der Paketname `vofi` ist auf CRAN frei
(Abfrage vom 25.10.2026).

### 3.3 Namenskonventionen

| Element | Konvention | Beispiel |
|---|---|---|
| Exportierte Funktionen | Präfix `vofi_`, Verb_Substantiv, snake_case | `vofi_read_scenario()`, `vofi_export_excel()` |
| Interne Funktionen | Modulpräfix, kein Export | `eng_balance()`, `smp_uniforms()`, `val_check_refs()`, `io_xlsx_read_sheet()` |
| Typdefinitionen | `typedef_<typname>()` liefert die Definition (Auto-Discovery) | `typedef_annuity_loan()` |
| Build-/Step-Funktionen der Typen | `<art>_<typname>_<rolle>()` | `inst_annuity_loan_step()`, `flow_rent_build()` |
| Dateien | `<schicht>-<thema>.R`, ein Typ je Datei | `engine-balance.R`, `type-inst-annuity-loan.R` |
| S3-Klassen | `vofi_<ding>` | `vofi_result`, `vofi_mc_result` |
| Bedingungsklassen | `vofi_error_<art>`, `vofi_warning_<art>` | `vofi_error_validation`, `vofi_warning_library_outdated` |
| Optionen | `vofi.<name>` | `vofi.library_paths`, `vofi.chunk_size` |
| Eingabeschlüssel | englisch, snake_case, **Einheit als Suffix** | `amount_eur`, `rate_pa`, `living_area_m2`, `rent_eur_m2_month`, `term_years` |
| Zeilenschlüssel (Ledger) | nach Memo 01 §2.2 | `equity_in`, `loan_kfw_interest`, `od_draw`, `dep_interest`, `balance_check` |
| Enum-Werte | ASCII-snake_case. Deutsche Fachbegriffe sind zulässig, wenn keine eindeutige englische Entsprechung existiert (Codes aus Memo 02 übernehmen). | `selbstnutzer`, `wu_kommunal`, `sanierung_eh`, `bgb_559e`, `equity_call` |
| Sammlungen | intern immer **benannte Listen (Map nach id)**. Listen mit `id`-Feld werden beim Einlesen umgewandelt. | `measures: {daemmung: {...}}` |
| Testdateien | `test-<R-Datei ohne .R>.R` | `test-engine-balance.R` |
| Labels | Katalogschlüssel `<bereich>.<objekt>.<feld>` | `types.annuity_loan.params.rate_pa.label` |

Einheitensuffixe: `_eur`, `_eur_pa`, `_eur_m2`, `_eur_m2_month`, `_eur_kwh`, `_eur_t` (je t CO2), `_pa` (Rate p. a.,
**Dezimalzahl**), `_share` (0…1), `_years`, `_months`, `_year` (Kalenderjahr), `_date`, `_period` (Rasterindex), `_m2`,
`_kwh`, `_kwh_m2a`, `_kwp`, `_t_co2`.

### 3.4 Sprache, Umlaute und `R CMD check` (getestet)

Ein Testpaket mit einer Funktion, die `"Finanzierungssaldo – Bestandsgrößen"` zurückgibt, ergab:

```text
* checking R files for non-ASCII characters ... WARNING
Found the following file with non-ASCII characters: f.R
Portable packages must use only ASCII characters in their R code, except perhaps in comments.
```

Dasselbe Paket mit dem Text in `inst/labels/de.yaml` (Abruf über `system.file()` und `yaml::read_yaml()`) und deutscher
roxygen-Doku mit Umlauten ergab **`Status: OK`**. Daraus folgen diese Regeln:

1. **R-Code ist ASCII.** Alle Nutzertexte (Zeilenbeschriftungen, Meldungen, Berichtsüberschriften, Excel-Blattnamen)
   stehen in `inst/labels/de/*.yaml` und werden über `lbl("report.vofi.title")` bzw. `msg("validation.not_number",
   path = p, value = v)` abgerufen. Platzhalter folgen dem Muster `{path}`, ersetzt von einer eigenen Mini-Funktion
   (ohne glue). In Ausnahmefällen sind `ä`-Escapes zulässig.
2. **Kommentare** im R-Code dürfen deutsch sein, auch mit Umlauten (erlaubt).
3. **roxygen-Doku auf Deutsch** mit Umlauten (Rd-Dateien in UTF-8, `Encoding: UTF-8`).
4. **CI-Umgebung mit `LANG=C.UTF-8`**. Ohne passendes Locale meldet `R CMD check` im Container eine weitere WARNING
   (`Sys.setlocale("LC_CTYPE", "en_US.UTF-8")` cannot be honored). Snapshot-Tests mit Umlauten laufen nur in einer
   UTF-8-Session (`skip_if_not(l10n_info()[["UTF-8"]])`).
5. Der Label-Katalog wird in `.onLoad` geladen und zusammengeführt (eine Datei je Modul und Typ, daher keine
   Merge-Konflikte). Fehlende Schlüssel erzeugen in Tests einen Fehler und zur Laufzeit den Schlüssel selbst als
   sichtbaren Platzhalter.
6. Der Katalog ermöglicht später eine englische Oberfläche (`options(vofi.language = "en")`), ohne Codeänderung.

### 3.5 roxygen2 auf Deutsch (Muster)

```r
#' Vollständigen Finanzplan berechnen
#'
#' Berechnet für ein gebautes Modell den Vollständigen Finanzplan (VoFi). Mit
#' `n_sim = 1` wird deterministisch mit den Basiswerten aller unsicheren
#' Parameter gerechnet, mit `n_sim > 1` als Monte-Carlo-Simulation.
#'
#' @param model Ein Objekt der Klasse `vofi_model`, erzeugt mit [vofi_build()].
#' @param n_sim Anzahl der Simulationsläufe (ganze Zahl >= 1).
#' @param seed Startwert des Zufallszahlengenerators. `NULL` übernimmt
#'   `stochastic$settings$seed` aus dem Szenario.
#' @param store Umfang der gespeicherten Zwischenergebnisse, siehe Abschnitt
#'   „Speicherstrategie“.
#' @param chunk_size Läufe je Rechenblock (Vielfaches von 1.000); steuert
#'   nur den Speicherbedarf, nicht die Ergebnisse.
#' @return Bei `n_sim = 1` ein Objekt der Klasse `vofi_result`, sonst
#'   `vofi_mc_result`.
#' @family Rechnen
#' @examples
#' sz <- vofi_read_scenario(vofi_example("s4_selbstnutzer_efh_1975"))
#' m  <- vofi_build(sz)
#' vofi_run(m)
#' @export
vofi_run <- function(model, n_sim = 1L, seed = NULL,
                     store = c("auto", "full", "bands", "kpi"),
                     chunk_size = getOption("vofi.chunk_size", 10000L)) { … }
```

`@family`-Gruppen (deutsch): Einlesen, Validieren, Rechnen, Analysieren, Berichten, Erweitern.

### 3.6 Glossar der Kernbegriffe (verbindlich für alle Agenten)

| Deutsch (Anzeige) | Bezeichner | Bemerkung |
|---|---|---|
| Zahlungsfolge der Investition (originär) | section `project` | Zeilen der Cashflow-Komponenten |
| Investitionszuschüsse (zahlungswirksam) | section `grants`, key `grant_cash` | Memo 01 Z. 2 |
| Einlage / Entnahme / Nachschuss | `equity_in` / `equity_out` / `equity_call` | Nachschuss = Policy D4 |
| Kredit k: Aufnahme / Tilgung / Sondertilgung / Sollzinsen / Gebühren | `loan_<k>_draw` / `_repay` / `_prepay` / `_interest` / `_fees` | Memo 01 Z. 5–9 |
| Kontokorrent: Aufnahme / Tilgung / Sollzinsen | `od_draw` / `od_repay` / `od_interest` | |
| Geldanlage: Anlage / Auflösung / Habenzinsen | `dep_invest` / `dep_withdraw` / `dep_interest` | |
| Steuern (Slot) | `tax` | v1 = 0 |
| Finanzierungssaldo | `balance_check` | muss 0 sein |
| Kreditstand, Kontokorrentstand, Guthabenstand | `loan_<k>_balance`, `od_balance`, `dep_balance` | Bestände |
| Bestandssaldo BS | `net_position` | G − KK − Σ B |
| Tilgungszuschuss (Merkzeile) | `loan_<k>_repayment_grant` | `cash = FALSE` |
| VoFi-Endwert EW / EW Unterlassung / ΔEW | `terminal_value` / `terminal_value_opp` / `delta_terminal_value` | KPI-Schlüssel |
| EK-Rentabilität klassisch / modifiziert (R3) / Equity-IRR (R2) | `roe_classic` / `roe_mirr` / `roe_irr` | Memo 01 E4 |
| Unterlassungsalternative | `opportunity` | `vofi_opportunity()` |
| Restwert | `residual_value` | Memo 01 E12 |
| Ohnehin-/Sowieso-Kosten | `ohnehin_share` | Memo 02 §1.4 |
| Modernisierungsumlage | `modernization_levy` | § 559 BGB |
| Ersparte Miete (Selbstnutzer) | `imputed_rent` | |
| Parameterbibliothek / Eintrag | `library` / `entry` | |
| Rechtsstand | `legal_state` | Memo 02 |

---

## 4. Eingabeformat

### 4.1 Verarbeitungskette

```text
 YAML-Datei ─┐                         ┌─ Bibliothek (inst/extdata/library, Nutzerpfade)
             ├─► Lesen/Normalisieren ─►│
 Excel-Datei ┘   (io-yaml, io-excel)   └─ Profile, Defaults
                       │
                       ▼
            vofi_scenario  (kanonische Liste: Basis + Unsicherheiten + Varianten, mit Herkunft)
                       │  vofi_resolve(variant)          Schichten mergen, from: auflösen, Expander
                       ▼
            vofi_spec      (vollständig aufgelöste Variante, nur Komponentenebene, Werte normalisiert)
                       │  vofi_validate()                Struktur, Typen, Querbezüge, Plausibilität
                       ▼
            vofi_model     (Raster, sortierte Knoten, Sampler-Plan, Ausgleichsketten, Steuermodul, KPI-Set)
                       │  vofi_run()/vofi_mc()           Sampling ─► Komponenten ─► Periodenschleife ─► KPIs
                       ▼
     vofi_result | vofi_mc_result | vofi_comparison     ─► print/plot/Excel/HTML/Shiny
```

### 4.2 Kanonische Struktur (Schema v1)

| Block | Inhalt | Ebene |
|---|---|---|
| `schema_version` | ganze Zahl (1) | Meta |
| `meta` | `scenario_id`, `title`, `author`, `created_date`, `description`, `tags` | Meta |
| `project` | `perspective`, `project_type`, `comparison_mode`, `valuation_date`, `application_date`, `horizon_years`, `legal_state`, `pending_reforms`, `federal_state` … (Memo 02 §9.1) | Domäne |
| `grid` | Bauphase (`construction_months`, `construction_step: month|quarter`), Betrieb (`operation_step: year`), Horizontbezug | Raster |
| `building` | Memo 02 §9.2 (`building_type`, `construction_year`, `n_units`, `living_area_m2`, Energiezustand …) | Domäne |
| `unit_groups` | Map: Wohnungsgruppen (Anzahl, Fläche, Ausgangsmiete, Mietregime, Selbstnutzung) | Domäne |
| `measures` | Map: Maßnahmen (DIN-276-KG, Kosten, Ohnehin-Anteil, Nutzungsdauer, Modernisierungsart, Fördereignung, Fertigstellung) | Domäne |
| `energy` | Energiesystem vorher/nachher | Domäne |
| `funding` | Map: Förderinstrumente (meist `from:` Bibliothek, Schema nach Memo 02 §5.8) | Domäne |
| `components` | Map: explizite Zahlungskomponenten (`type` + Parameter), ergänzend oder statt Domänenebene | Komponenten |
| `financing` | Map: EK-Budget, Einlagen/Entnahmen, Kredite (`type` + Parameter) | Komponenten |
| `accounts` | Habenzins, KK-Zins, KK-Limit, Mindestliquidität, Ausgleichsketten (`surplus_order`, `deficit_order`), Engpass-Policy | Engine |
| `market` | deterministische Marktannahmen als Basisfall: Inflation, Mietsteigerung, Energiepreise, CO2-Preis, Anschlusszins, Baupreisindex (Konstante oder Zeitreihe); Komponenten verweisen per `{ref: market.…}` darauf | Markt |
| `stochastic` | **Overlay nach Memo 04 §10**: `settings` (n_sim, seed, sampling, replicates, copula, store, keep_runs), `parameters` (statische Größen: `target` → Verteilung), `processes` (Zeitreihen: `target` → Prozess), `correlations` (`parameters`, `shocks`). Kann auch als eigene Datei geladen werden (mehrere Stochastik-Profile je Projekt) | Unsicherheit |
| `analysis` | `kpis`, `deterministic_point`, Pflichtsensitivitäten | Auswertung |
| `tax` | `module: none` (v1), Parameter späterer Module | Steuer |
| `variants` | Map: Varianten mit `label`, `extends`, `overrides` bzw. `set`/`remove` | Varianten |

### 4.3 YAML-Beispiel (gekürzt, Mechanismen im Vordergrund)

```yaml
schema_version: 1
meta:
  scenario_id: mfh_musterstr_12
  title: "Energetische Sanierung MFH Musterstraße 12"
  author: "Controlling"
  created_date: 2026-10-25
project:
  perspective: wu_kommunal            # Codes nach Memo 02
  project_type: sanierung_eh
  comparison_mode: absolute           # Total-VoFi je Alternative (Memo 01 E6)
  valuation_date: 2027-01-01
  horizon_years: 30
  legal_state: 2026-10-25
grid:
  construction_months: 9
  construction_step: month
building:
  building_type: MFH
  construction_year: 1972
  n_units: 18
  living_area_m2: 1250
unit_groups:
  standard:
    n_units: 18
    rent_eur_m2_month: 7,20           # Dezimalkomma wird akzeptiert (Hinweis im Bericht)
measures:
  huelle:
    label: "Dämmung Fassade/Dach, Fenster"
    cost_eur: 1350000
    ohnehin_share: 0.25
    useful_life_years: 40
    modernization_kind: bgb_555b_1
  waermepumpe:
    cost_eur: 450000
    useful_life_years: 20
    modernization_kind: bgb_555b_1a
funding:
  kfw261:
    from: funding/kfw_261_eh55        # Bibliotheksverweis; lokale Werte überschreiben
    amount_eur: 1200000
financing:
  ek:
    type: equity
    amount_eur: 400000
  bank:
    type: annuity_loan
    amount_eur: auto                  # deckt den verbleibenden Bedarf je Lauf
    rate_pa: 0.039
    initial_repayment_pa: 0.02
    fixed_years: 10
    followup_rate_pa: {ref: market.mortgage_rate}   # Basisfall aus market, in der MC Prozesspfad
    refi_rule: keep_tilg_rate
accounts:
  deposit_rate_pa: 0.02
  overdraft_rate_pa: 0.085
  overdraft_limit_eur: 250000
  min_liquidity_eur: 0
  surplus_order: [od_repay, dep_fill_reserve, dep_invest]       # Ü1, Ü2, Ü4 (Ü3 aus)
  deficit_order: [dep_withdraw, od_draw, dep_use_reserve, penalty_rate]
  penalty_spread_pa: 0.04
market:                                # Basisfall (deterministisch)
  inflation: 0.02
  rent_growth: 0.02
  mortgage_rate: 0.045
  co2_price: {from: prices/co2_price_paths_2026, use: mittel}   # Pfad "mittel" als Basisfall
stochastic:                            # Overlay nach Memo 04 §10 (auch als eigene Datei möglich)
  settings: {n_sim: 10000, seed: 20261025, sampling: lhs, replicates: 10,
             copula: iman_conover, store: bands, keep_runs: [p05, p50, p95]}
  parameters:
    huelle_kosten:
      target: measures.huelle.cost_eur
      label: "Kosten Gebäudehülle"
      dist: pert
      min: 1250000
      mode: 1350000
      max: 1750000
  processes:
    inflation:      {target: market.inflation, type: ar1, mu: 0.02, phi: 0.5, sigma: 0.011, x0: 0.022}
    rent_growth:    {target: market.rent_growth, type: linked_ar1, base: inflation, a: 0.002, b: 0.8,
                     phi: 0.5, sigma: 0.006}
    mortgage_rate:  {target: market.mortgage_rate, from: processes/mortgage_rate_vasicek_2026}
    co2_price:      {target: market.co2_price, from: prices/co2_price_paths_2026}   # scenario_mix
  correlations:
    shocks:
      - [inflation, mortgage_rate, 0.4]
tax:
  module: none
variants:
  status_quo:
    label: "Unterlassung: nur Ohnehin-Instandhaltung"
    remove: [measures.waermepumpe, funding.kfw261]
    set:
      measures.huelle.cost_eur: 337500          # nur Ohnehin-Anteil
  eh55_ohne_foerderung:
    label: "EH 55 ohne KfW"
    extends: base
    overrides:
      funding:
        kfw261: ~                               # ~ (null) entfernt den Eintrag
```

### 4.4 Grammatik der Wertangaben

Jeder numerische Parameter darf eine der folgenden Formen haben. Der Normalisierer (`values.R`) überführt sie in eine
einheitliche interne Darstellung `list(kind = …)`. Typen fragen Werte nur über `ctx$param()` ab und bekommen immer
einen N-Vektor (`shape = "scalar"`) oder eine N × (T+1)-Matrix (`shape = "path"`).

| Form | YAML | Intern | Ergebnis im Lauf |
|---|---|---|---|
| Konstante | `0.039` | `const` | N-Vektor bzw. Matrix mit konstantem Wert |
| Zeitreihe | `[1000, 1000, 2000]` oder `{series: {2027: 1000, 2030: 2000}, fill: locf}` | `series` | Matrix, Kalenderjahre auf das Raster abgebildet |
| Verteilung (je Lauf konstant) | kanonisch im Overlay `stochastic.parameters` mit `target`; inline `{dist: pert, min: …, mode: …, max: …}` als Kurzform (wird beim Normalisieren ins Overlay verschoben) | `dist` | N-Vektor, deterministisch = Basiswert |
| Bezug | `{ref: building.living_area_m2}`, `{ref: market.rent_growth}` ggf. mit `scale`, `offset` | `ref` | Wert eines anderen Pfades. Zielt ein Prozess des Overlays auf diesen Pfad, ist es in der MC dessen N × (T+1)-Pfad |
| Wachstum | `{start: 7.2, growth: {ref: market.rent_growth}}` oder `growth: 0.02` | `growth` | Startwert × kumulierter Index |
| Ausdruck (eingeschränkt) | `{expr: "building.n_units * 150000"}` | `expr` | sichere Auswertung (4.12) |
| Mengenbezug (Memo 07 A-14) | `{value: 14, per: m2_living_area}`; `per` ∈ `total`, `unit`, `m2_living_area`, `m2_component:<bauteil>`, `kw`, `kwp`, `kwh` | `quantity` | Wert × Bezugsgröße aus `building` (z. B. `component_areas_m2`) |
| Automatisch | `auto` (nur zugelassene Parameter, z. B. Kreditbetrag) | `auto` | vom Build/der Engine bestimmt |

Der **Basiswert** für den deterministischen Lauf ist der deterministische Wert am Zielpfad (Overlay-Prinzip nach
Memo 04 §10.1). Weicht `mode` davon ab, gibt die Validierung einen Hinweis aus. Liegt der Basiswert außerhalb
[min, max], ist das ein Fehler. Nur bei der Inline-Kurzform ohne deterministischen Wert gilt `base:` bzw.
`analysis$deterministic_point` (`mode` | `median` | `mean`). Die Ausgabe weist ausdrücklich darauf hin, dass der
deterministische VoFi nicht dem MC-Erwartungswert entspricht (Nichtlinearität des Ausgleichs, Jensen).

### 4.5 Einheiten, Zahlen und Datumsangaben (YAML-Fallstricke, getestet)

Ergebnisse von `yaml::yaml.load()` (yaml 2.3.8) für typische Eingaben deutscher Nutzer:

| Eingabe | Standard-Parser liefert | Risiko | Regel im Tool |
|---|---|---|---|
| `3,5` | `NA` (int) mit Warnung | Wert geht verloren | Eigener `int`-Handler erkennt das Komma und liefert 3,5 mit Hinweis im Validierungsbericht. In Anführungszeichen (`"3,5"`) landet der Wert beim `str`-Handler, der dieselbe Regel anwendet |
| `"3,5 %"`, `"3.5%"` | Zeichenkette | – | `str`-Handler wandelt in 0,035 um (Einheit `%` wird vermerkt) |
| `150.000` (Tausenderpunkt) | **150** (float) | **stiller Faktor-1000-Fehler** | `float`-Handler markiert das Muster `^[1-9]\d{0,2}\.\d{3}$`. Bei Parametern mit Einheit EUR ist das ein **Fehler**, sonst eine Warnung. Empfehlung in der Doku: `150000` schreiben |
| `1.234.567` | Zeichenkette | – | Umwandlung in 1234567 mit Hinweis |
| `150_000` | Zeichenkette | – | Umwandlung in 150000 |
| `1e-2` | Zeichenkette (YAML 1.1) | – | Umwandlung in 0,01 |
| `2026-01-01` | Zeichenkette | – | Umwandlung, wo das Schema `date` verlangt |
| `yes`/`no` | logisch | „no“ als Text gemeint | Schema prüft den Typ. `ja`/`nein` werden für logische Felder akzeptiert |

Die Handler werden über `yaml::yaml.load(..., handlers = list(int = …, float = …, str = …))` eingebunden (im
Prototyp geprüft). Weitere Regeln:

- **Raten und Anteile sind Dezimalzahlen** (`rate_pa: 0.039`). Ein Wert > 1 bei `_pa`/`_share` ist ein **Fehler** mit
  Vorschlag („3,9 ist als 0.039 oder "3,9 %" anzugeben“). Es gibt keine stille Umdeutung.
- **Kanonische Einheit je Parameter** steht im Parameterschema des Typs (`unit = "EUR/m2/Monat"`). Andere Einheiten
  werden nicht umgerechnet. In Excel zeigt eine schreibgeschützte Spalte die Einheit, eine geänderte Einheitenzelle
  ist ein Fehler.
- **Geldbeträge nominal in EUR, brutto** (Wohnraumvermietung ist umsatzsteuerfrei, Vorsteuer nicht abziehbar). Für
  Bibliothekskosten gilt ein `price_base_year`. Die Fortschreibung auf das Raster läuft über
  `market.construction_price_index` (Memo 01 E8: Rechnung nominal, reale Ausgabe nur durch Deflationierung).
- **Dateikodierung UTF-8, robust gelesen**: Unter Locale `C`/`POSIX` bricht `yaml::read_yaml()` an Umlauten ab
  (geprüft: „Scanner error … unexpected end of stream“). Alle YAML-Dateien (Szenarien, Bibliothek, Label-Katalog)
  liest deshalb ein Helfer `io_read_yaml_utf8()` =
  `yaml::yaml.load(paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n"), handlers = …)`
  (geprüft: liefert unter `C` korrekte UTF-8-Zeichenketten; Befund deckt sich mit Memo 04 §10.1).
- **Excel**: Zellen speichern Zahlen gebietsschemaunabhängig. Prozentformatierte Zellen enthalten bereits Dezimalwerte
  (3,9 % → 0,039). Als Text eingefügte Zahlen („1.234,56“) wandelt der Excel-Leser mit Hinweis um.

### 4.6 Schichten, Deep-Merge und Herkunft

**Reihenfolge** (spätere Schicht gewinnt):

| Nr. | Schicht | Quelle |
|---:|---|---|
| 0 | Typ-Defaults | Parameterschema in der Registry |
| 1 | Globale Defaults | `inst/extdata/defaults/global.yaml` |
| 2 | Perspektiven-Profil | `inst/extdata/profiles/<perspective>.yaml` (z. B. KK-Limit, Policy D4 nach Memo 01 §3.2) |
| 3 | Rechtsstand und Bibliothekseinträge | `legal_state` und `from:`-Verweise (Kette erlaubt, Zyklen sind ein Fehler) |
| 4 | Nutzerbibliotheken | `vofi_library_paths()` bzw. `options(vofi.library_paths = …)`, z. B. Unternehmensstandards |
| 5 | Szenario-Basis | Datei |
| 6 | Stochastik-Overlay | Block bzw. Datei `stochastic` (Memo 04 §10). Wirkt nur in der MC. Basisfall, Tornado und Break-even rechnen mit den deterministischen Werten der Schichten 0–5 |
| 7 | Variante(n) | `extends`-Kette, dann `overrides`/`set`/`remove` |
| 8 | Laufzeit-Overrides | `vofi_build(x, overrides = list("financing.bank.rate_pa" = 0.045))`, Shiny, Sensitivität |

**Merge-Semantik** (`utils-merge.R`):

```r
deep_merge <- function(base, override) {
  if (!is_map(base) || !is_map(override)) return(override)   # Skalare/Vektoren/Sequenzen: ersetzen
  if (isTRUE(override[[".replace"]])) {                      # Map vollständig ersetzen
    override[[".replace"]] <- NULL
    return(override)
  }
  for (nm in names(override)) {
    if (is.null(override[[nm]])) base[[nm]] <- NULL          # explizites ~ (null) löscht
    else base[[nm]] <- deep_merge(base[[nm]], override[[nm]])
  }
  base
}
```

- Maps werden rekursiv gemischt. Skalare, Vektoren und YAML-Sequenzen werden **ersetzt**, nicht elementweise gemischt.
  Deshalb sind Sammlungen Maps nach id.
- `~` (null) löscht einen Schlüssel. Das yaml-Paket behält null-Einträge als `NULL`-Elemente (geprüft).
- Pfadoperationen (`set`, `remove`) sind gleichwertig zu Baum-Overrides. Intern wird alles in eine Liste von
  Pfadoperationen übersetzt.
- **Herkunft:** `vofi_spec` trägt ein Attribut `provenance` (Data Frame: `path`, `layer`, `file`, `entry`, `cell`,
  `valid_from`, `valid_to`, `accessed`). Es erscheint im Excel-Blatt „Annahmen“ und im Bericht.

### 4.7 Bibliothek und Verweise

- **Ein Eintrag je Datei**, Pfad = id (`funding/kfw_261_eh55`). Das erlaubt paralleles Pflegen und saubere
  Git-Historien.
- Pflichtmetadaten nach Memo 02 §10: `source` (Dokument, URL), `accessed`, `valid_from`, `valid_to`, `uncertainty`
  (optional), `schema_version`, `block` (Zielblock: `funding` | `financing` | `processes` | `components` | `legal` …; bewusst nicht `target`, das im Overlay einen Pfad bezeichnet).
- `from:` merged die Werte des Eintrags *unter* die lokale Angabe (lokal gewinnt).
- **Validierung:** Liegt `application_date` außerhalb von `valid_from`/`valid_to`, gibt es eine Warnung, ebenso wenn
  `accessed` älter als 6 Monate ist (Memo 02 §10 Nr. 5).
- Einträge in Listenform (Memo 02, `- id: …`) werden beim Laden in Maps nach `id` umgewandelt.
- `vofi_library()` listet Einträge mit Metadaten. `vofi_freeze(scenario, path)` (v1.1) schreibt ein vollständig
  aufgelöstes Szenario fürs Archiv.
- Jedes Ergebnis speichert die aufgelöste Spezifikation. Eine spätere Bibliotheksaktualisierung ändert alte Ergebnisse
  also nicht.

### 4.8 Varianten

- `base` ist implizit die Basisvariante. Jede Variante hat `label` (deutsch), optional `description` und `extends`
  (Standard `base`; Ketten erlaubt, Zyklen sind ein Fehler). `project$reference_variant` (Memo 07) ist die
  Standard-Basis für `vofi_compare()`.
- **Explizite Operationen** (Memo 07 A-04: Vererbung nur mit ausdrücklichen Operationen, sonst Fehlerquelle). Intern
  wird jede Variante in eine geordnete Liste von Pfadoperationen übersetzt:

  | Operation | Wirkung | Prüfung |
  |---|---|---|
  | `set: {pfad: wert}` | Wert setzen; bei Maps Deep-Merge | Fehler, wenn der Pfad in der Elternvariante nicht existiert (Schutz vor Tippfehlern, die sonst still einen neuen Schlüssel anlegen) |
  | `replace: {pfad: wert}` | Teilbaum vollständig ersetzen | Pfad muss existieren |
  | `add: {sammlung.id: {...}}` | neuen Eintrag anlegen (Maßnahme, Kredit, Komponente) | Fehler, wenn die id schon existiert |
  | `remove: [pfad, …]` | Eintrag löschen | Pfad muss existieren |

  Die Baumform `overrides:` (wie im YAML-Beispiel) ist Kurzschrift für `set` mit derselben Existenzprüfung. `~` (null)
  in `overrides` entspricht `remove`.
- **Gemeinsame Bausteine** über YAML-Anker und -Aliase (`&wp`, `*wp`, Merge-Schlüssel `<<:`; das yaml-Paket
  unterstützt sie, `merge.precedence = "override"`) oder über einen Block `shared`, auf den `{ref: shared.…}` verweist.
- **Deterministische Szenario-Sets** (Memo 07 A-24, z. B. „Zinsschock“, „Förderstopp“) sind Varianten mit `set` auf
  `market`- bzw. `funding`-Pfaden. Sie lassen sich mit jeder Projektvariante kreuzen
  (`vofi_compare(sz, variants = …, scenario_sets = …)`).
- **Vergleichbarkeitsprüfung** beim Vergleich (Memo 01 §5.1): gleiche Horizonte, gleiches EK-Budget, gleiche
  Konto-Konditionen. Abweichungen sind ein Fehler, außer bei ausdrücklichem `allow_unequal: true`.
- `vofi_variants(sz)` listet die Varianten. `vofi_compare(sz)` rechnet alle Varianten mit gemeinsamen Zufallszahlen.
- Sensitivitäten und Break-even-Suchen erzeugen intern Varianten über Pfad-Overrides (Schicht 8). Es gibt nur einen
  Mechanismus.

### 4.9 Domänenebene und Expander

Memo 02 beschreibt die Eingabe fachlich (Gebäude, Wohnungsgruppen, Maßnahmen, Förderinstrumente, Rechtsstand). Die
Engine soll aber generisch bleiben. Deshalb übersetzen **Expander** (Registry-Art `expander`) die Domänenblöcke beim
Auflösen in typisierte Komponenten:

| Expander | Eingabe | Erzeugt |
|---|---|---|
| `expand_measures` | `measures` | je Maßnahme `capex`-Komponente (Kostenverteilung über Bauphase, Asset mit AfA-Basis und `cost_nature`), `replacement`-Zyklen nach Nutzungsdauer, Ohnehin-Anteil, förderfähige Kosten |
| `expand_unit_groups` | `unit_groups` + `legal_state` | `rent_path`-Komponente je Gruppe (Mietpfad nach Regelfunktionen §§ 558/559/559e, ggf. Monatsraster intern), `imputed_rent` bei Selbstnutzung |
| `expand_funding` | `funding` | je nach `instrument_type`: `grant` (Komponente), `loan`/`loan_with_repayment_grant` (Instrument), `interest_subsidy` (Instrument-Parameter) |
| `expand_energy` | `energy`, `building` | `energy_cost` (Selbstnutzer), `co2_cost` (Vermieteranteil nach CO2KostAufG) |
| `expand_residual` | `project`, Restwertmethode | `residual_value`-Komponente (Memo 01 E12) |

Erzeugte Komponenten tragen ids der Form `measures.huelle.capex` und eine Herkunft „Expander“. Sie erscheinen in
`print(spec)` und sind über Varianten überschreibbar. **Rechtsregeln** (Memo 02 §10 Nr. 2) sind reine, vektorisierte
Funktionen in `rules-*.R`, versioniert nach Rechtsstand (Registry-Art `rule`, Schlüssel `name` + `valid_from`), z. B.
`rule_bgb_559(costs, area, rent_before, legal_state)`. Gesetzesänderungen betreffen dann nur YAML und eine kleine
Regelfunktion.

### 4.10 Excel-Vorlage

**Prinzip:** Die Vorlage wird **aus Registry, Vokabularen und Label-Katalog generiert**
(`vofi_excel_template()`; die ausgelieferte `inst/templates/vofi_eingabe.xlsx` erzeugt `data-raw/build_template.R`).
Ein Test vergleicht die Struktur mit einer frisch generierten Vorlage, damit Vorlage und Code nicht auseinanderlaufen.

| Blatt | Layout | Inhalt |
|---|---|---|
| Anleitung | Text | Bedienung, Farblegende (gelb = Eingabe, grau = berechnet/gesperrt), Zahlenregeln |
| Projekt | Schlüssel-Wert | `meta`, `project`, `grid`, `accounts`, `analysis`, `tax` |
| Markt | Schlüssel-Wert bzw. Zeitreihe | `market` (Basisfall der Marktannahmen) |
| Gebäude | Schlüssel-Wert | `building`, `energy` |
| Wohnungsgruppen | breit, eine Zeile je Gruppe | `unit_groups` |
| Maßnahmen | breit, eine Zeile je Maßnahme | `measures` |
| Förderung | breit | `funding` (Bibliothekseintrag per Auswahlliste + lokale Abweichungen) |
| Finanzierung | breit | `financing` (Typ per Auswahlliste, typspezifische Spalten, nicht zutreffende ausgegraut) |
| Komponenten | lang: id, Typ, Parameter, Wert | zusätzliche typisierte Komponenten |
| Zeitreihen | id, Parameter, Einheit, Spalten je Jahr | explizite Reihen (`custom_series`, Abrufpläne) |
| Stochastik-Einstellungen | Schlüssel-Wert | `stochastic.settings` |
| Unsicherheiten | id, Ziel (Pfad), Bezeichnung, Verteilung, P1–P4, Kommentar | `stochastic.parameters` |
| Prozesse | lang: id, Ziel, Typ, Parameter, Wert | `stochastic.processes` |
| Korrelationen | Art (Parameter/Schocks), Größe A, Größe B, ρ | `stochastic.correlations` |
| Varianten | Variante, Bezeichnung, basiert auf, Pfad, Aktion (setzen/entfernen), Wert | `variants` |
| Listen (ausgeblendet) | – | Auswahllisten (Typen, Verteilungen, Perspektiven, Enums) |
| _meta (ausgeblendet) | – | `schema_version`, Vorlagenversion, Paketversion |

Details:
- **Zeile 1 enthält die Maschinenschlüssel** (ausgeblendet, gesperrt), Zeile 2 die deutschen Überschriften, ab Zeile 3
  folgen Daten. Der Leser orientiert sich an Zeile 1, umbenannte Überschriften schaden nicht.
- **Auswahllisten** über `openxlsx::dataValidation(type = "list", value = "'Listen'!$A$2:$A$n")` (im Prototyp
  geprüft; openxlsx 4.2.5 gibt dabei eine harmlose `sprintf`-Warnung aus, die im Paket unterdrückt wird).
- Auswahllisten zeigen deutsche Bezeichnungen (z. B. „Selbstnutzer“). Der Leser übersetzt über das Vokabular in
  Codes.
- **Zahlenformate** im Code mit englischer Formatsyntax (`"#,##0 \u20ac"`, `"0.00%"`; das €-Zeichen im R-Code als Escape). Ein deutsches Excel zeigt sie
  lokalisiert an („1.234 €“, „3,90 %“).
- **Zellbezug in der Herkunft**: Fehlermeldungen nennen Blatt und Zelle („Blatt ‚Finanzierung‘, Zelle E5: Zinssatz 3,9
  ist größer als 1 …“). Für YAML gibt das yaml-Paket keine Zeilennummern zurück, die Meldung nennt den Pfad. Die Zeile
  wird bestmöglich per Textsuche ergänzt.
- **Round-Trip:** `vofi_write_scenario(sz, "x.xlsx")` und `vofi_read_scenario("x.xlsx")` ergeben dieselbe kanonische
  Liste (Test). So lassen sich YAML-Beispiele für Praktiker als Excel ausliefern und Excel-Szenarien als YAML in Git
  versionieren.

### 4.11 Validierung

Eine **eigene R-DSL** für Parameterschemata statt JSON-Schema-Validierung (jsonvalidate bräuchte V8). Gründe: deutsche
Meldungen, registryabhängige Typparameter, Querbezüge. Aus der DSL wird optional ein JSON-Schema exportiert
(`vofi_json_schema()`, jsonlite in Suggests), das Editoren mit YAML-Language-Server für Autovervollständigung nutzen.

| Ebene | Prüfungen | Schwere |
|---|---|---|
| 1 Struktur | bekannte Blöcke und Schlüssel (bei Tippfehlern Vorschlag per `utils::adist`, z. B. „Meinten Sie `rate_pa`?“), Pflichtfelder, Grundtypen | Fehler |
| 2 Typparameter | Schema je Typ: Datentyp, Bereich, Enum, Einheit, ob stochastisch erlaubt, ob `auto` erlaubt | Fehler |
| 3 Querbezüge | Referenzen existieren (`of:`, `ref:`, `from:`, `target:` im Overlay, `base:` bei verknüpften Prozessen), keine Zyklen, Zinsbindung ≤ Laufzeit, Perioden im Horizont, Summen der Teilauszahlungen = Zusage, `min ≤ mode ≤ max`, Korrelationsmatrix positiv definit (`chol`), s ≥ h (Memo 01 §3.1 Nr. 6: Warnung), Horizont ≥ Bauphase | Fehler/Warnung |
| 4 Plausibilität | Baukosten je m², Mieten, Zinsen außerhalb üblicher Bandbreiten, Tausenderpunkt-Verdacht, Bibliothek veraltet, Horizont > Nutzungsdauer | Warnung/Hinweis |

- `vofi_validate()` **sammelt alle** Befunde, statt beim ersten abzubrechen, und liefert ein `vofi_validation`-Objekt
  (Data Frame `severity`, `path`, `location`, `message`) mit deutschem `print`.
- `vofi_build()` bricht bei Fehlern mit der Bedingung `vofi_error_validation` ab (Bericht im Feld `$report`).
- Typen definieren optional `validate(spec, scenario)` für typspezifische Querbezüge.

### 4.12 Sichere Ausdrücke (Förderbedingungen, abgeleitete Werte)

Memo 02 §5.8 verwendet Bedingungen wie `"unit.owner_occupied & heating.replaced_fossil_functional"`. Statt `eval()`
gibt es einen **Whitelist-Auswerter** (`expr.R`): `parse(text = x)`, dann ein rekursiver Gang über den Syntaxbaum. Zugelassen
sind nur `+ - * / ^ %% ( < <= > >= == != & | ! && || %in% ifelse pmin pmax min max abs round floor ceiling is.na c`,
Zahlen, Zeichenketten, `TRUE`/`FALSE` und Symbole. Symbole mit Punkt (`building.n_units`) werden als Pfad im
aufgelösten Szenario gelesen (R parst sie als *ein* Symbol). Die Auswertung ist vektorisiert (stochastische Größen
liefern N-Vektoren). Unbekannte Funktionen oder Symbole sind Validierungsfehler. YAML wird grundsätzlich ohne
`eval.expr` gelesen.

---

## 5. Registry/Plugin-Mechanismus und Steuer-Hook

### 5.1 Arten (kinds)

| Art | Zweck | Schnittstelle (alle Werte vektorisiert über N) |
|---|---|---|
| `flow` | originäre Zahlungen, Zuschüsse, geplante EK-Ströme | `build(spec, ctx)` → `vofi_flows` |
| `instrument` | Kredite als Zustandsautomaten | `init(spec, ctx)` → Zustand; `step(state, t, ctx)` → `list(state, flows, memo)`; optional `prepay(state, amount, t, ctx)` → `list(state, used, flows)` (Ü3) |
| `account_action` | Ausgleichsschritte Ü1–Ü4, D1–D4, Engpass-Policies | `apply(acc, amount, t, ctx)` → `list(acc, used, flows, flags)` |
| `expander` | Domänenblöcke → Komponenten | `expand(block, scenario)` → `list(components, financing, assets)` |
| `distribution` | Zufallsverteilungen | `quantile(u, par)`, `point(par, which)`, `validate(par)`, `moments(par)` |
| `process` | stochastische Zeitreihenprozesse (Memo 04 §2.2) | `simulate(par, z, grid, ctx)` → N × (T+1); `expected(par, grid)` (Basisfallpfad); `n_shocks(par)`; Prozessparameter dürfen selbst verteilt sein (Memo 04 E3) |
| `kpi` | Kennzahlen | `compute(core, ctx)` → N-Vektor + NA-Gründe |
| `tax` | Steuermodule | Konstruktor eines Modulobjekts; S3-Methoden `tax_init`, `tax_step`, `tax_finalize` (5.10, Memo 06 §7.12) |
| `rule` | versionierte Rechtsregeln | Funktion, Auswahl nach `legal_state` |

### 5.2 Typdefinition (Felder) und Beispiel

```r
typedef_annuity_loan <- function() vofi_type(
  name        = "annuity_loan",
  kind        = "instrument",
  version     = 1L,
  perspectives = NULL,                          # NULL = alle
  params = list(
    amount_eur           = vofi_param("amount", required = TRUE, allow_auto = TRUE),
    rate_pa              = vofi_param("rate", required = TRUE, stochastic = TRUE),
    term_years           = vofi_param("integer", min = 1, max = 80, default = NULL),
    initial_repayment_pa = vofi_param("rate", default = NULL),
    fixed_years          = vofi_param("integer", min = 0, default = NULL),
    followup_rate_pa     = vofi_param("value", shapes = c("scalar", "path"), default = NULL),
    refi_rule            = vofi_param("enum", values = c("keep_term", "keep_tilg_rate", "keep_payment"),
                                      default = "keep_tilg_rate"),
    grace_years          = vofi_param("integer", min = 0, default = 0),
    draw_schedule        = vofi_param("value", shapes = "series", default = NULL),
    payout_rate          = vofi_param("share", default = 1),          # Auszahlungskurs (Disagio)
    commitment_fee       = vofi_param("map", default = NULL),         # Bereitstellungsprovision
    repayment_grant      = vofi_param("map", default = NULL),         # Betrag, Zeitpunkt, Wirkung
    payments_per_year    = vofi_param("integer", values = c(1L, 4L, 12L), default = 12L)
  ),
  rows   = c("draw", "repay", "prepay", "interest", "fees"),     # deklarierte Zeilen
  stocks = "balance",
  memo   = "repayment_grant",
  init   = inst_annuity_loan_init,
  step   = inst_annuity_loan_step,
  prepay = inst_annuity_loan_prepay,
  validate = inst_annuity_loan_validate,
  example  = list(amount_eur = 300000, rate_pa = 0.04, initial_repayment_pa = 0.02,
                  fixed_years = 10, followup_rate_pa = 0.05)
)
```

Texte für Label, Beschreibung, Parameterhilfe und Zeilenbeschriftungen stehen in
`inst/labels/de/types/annuity_loan.yaml`:

```yaml
label: "Annuitätendarlehen"
description: "Darlehen mit konstanter Rate aus Zins und Tilgung; Zinsbindung, Anschlusszins, tilgungsfreie Anlaufjahre, Tilgungszuschuss."
params:
  amount_eur: {label: "Darlehensbetrag", help: "Nennbetrag in EUR; 'auto' deckt den verbleibenden Finanzierungsbedarf."}
  rate_pa: {label: "Sollzins p. a. (nominal)"}
rows:
  draw: "Aufnahme"
  repay: "Tilgung"
  interest: "Sollzinsen"
  fees: "Provisionen und Gebühren"
  balance: "Kreditstand"
  repayment_grant: "Tilgungszuschuss (zahlungsunwirksam)"
```

Die Registrierung prüft: Namensmuster `^[a-z][a-z0-9_]*$`, gültige Art, Funktionssignaturen
(`function(spec, ctx)` bzw. `function(state, t, ctx)`), gültige Parameterschemata, vorhandenes `example`, vorhandene
Labels. Ein Überschreiben vorhandener Typen ist nur mit `overwrite = TRUE` möglich.

### 5.3 Kontext `ctx` (Vertrag)

`ctx` ist eine Umgebung, die die Engine je Chunk anlegt. Typen dürfen sie **nur lesen**.

| Element | Inhalt |
|---|---|
| `ctx$n`, `ctx$T` | Läufe im Chunk, letzter Periodenindex |
| `ctx$grid` | Raster: `t` (0…T), `delta` (Δ_t in Jahren), `tau`, `date_end`, `phase` (`construction`/`operation`), `label`; Helfer `index_of(date)`, `active(from, to)`, `rate_nom(r_pa)` = r·Δ, `rate_eff(r_pa)` = (1+r)^Δ − 1, `per_period(x_pa)`, `fine(step)` und `aggregate(x_fine)` für interne Monatsrechnung |
| `ctx$project`, `ctx$building` | aufgelöste Domänendaten (nur lesen) |
| `ctx$param(spec, name, shape)` | Parameterwert als N-Vektor oder N × (T+1)-Matrix (Konstante, Reihe, Ziehung, Bezug inkl. Prozesspfad, Ausdruck) |
| `ctx$market(name)` | Marktgröße als N × (T+1)-Pfad: Basisfall aus `market`, in der MC der Pfad des Prozesses, der auf `market.<name>` zielt |
| `ctx$zeros()`, `ctx$by_sim(x)`, `ctx$by_period(x)` | Nullmatrix; Broadcast eines N-Vektors (je Lauf) bzw. eines Zeitvektors der Länge T+1 (je Periode) auf N × (T+1). **Zwei getrennte Helfer, weil R beim Recycling `Matrix * Vektor` immer entlang der Zeilen ausrichtet:** `m * v` ist für einen N-Vektor richtig, für einen Zeitvektor falsch (bei N = T+1 sogar ohne Fehlermeldung). Zeitvektoren deshalb immer über `by_period()` |
| `ctx$component(id)` | Ergebnis (`vofi_flows`) einer **deklarierten** Vorgängerkomponente, sonst Fehler |
| `ctx$rows(filter)` | exogene Zeilen nach Tags (z. B. `category == "rent"`) |
| `ctx$need(phase)` | Finanzierungsbedarf je Lauf und Periode aus exogenen Zeilen (für `amount: auto`) |
| `ctx$rule(name)` | Rechtsregel zum `legal_state` |
| `ctx$lbl(key)`, `ctx$abort(key, ...)`, `ctx$warn(key, ...)` | Texte und strukturierte Meldungen mit Pfad der Komponente |

### 5.4 Rückgabevertrag: `vofi_flows`, `vofi_row`, `vofi_asset`

```r
vofi_row(key, values, section, category, tax_category, cash = TRUE, asset_id = NULL,
         measure_id = NULL, vat_rate = 0, vat_recoverable = FALSE, label = NULL, ...)
#  values: numerische Matrix N x (T+1), Bruttobeträge; Vorzeichen: Zufluss +, Abfluss -
#  ...: weitere Zahlungsbuch-Attribute nach Memo 06 §7.3 (tax_period, spread_years, program, is_tax ...)
vofi_asset(asset_id, asset_type, in_service_period, land_share = 0, afa_method = NULL,
           useful_life_override = NULL, construction_start_date = NULL,
           building_application_date = NULL, original_completion_year = NULL, acquisition_date = NULL)
vofi_measure(measure_id, measure_type, classification = c("auto", "erhaltung", "herstellung"),
             classification_source = "default", completion_date = NULL, funding_choice = NULL, ...)
vofi_flows(..., assets = list(), measures = list(), memo = list(), meta = list())
```

Die AfA-Bemessungsgrundlage ist bewusst **kein** Feld von `vofi_asset()`. Sie entsteht im Steuermodul aus den
zugeordneten Zeilen (Memo 06 §7.4).

Typen vergeben nur lokale Zeilenschlüssel (`"saving"`, `"interest"`). Den Ledger-Schlüssel setzt die Engine:
`<komponenten_id>_<zeile>` für Zahlungskomponenten (z. B. `pv_saving`), `loan_<k>_<zeile>` für Kredite (Memo 01
§2.2). So bleiben Schlüssel eindeutig, auch wenn ein Typ mehrfach vorkommt.

Der Vertragstest (`expect_vofi_flows_contract()`) prüft: alle Matrizen haben `dim = c(N, T+1)` und keine
`NA`/`Inf`-Werte, Tags stammen aus den Vokabularen, die Schlüssel sind eindeutig, Vorzeichen passen zur Kategorie (z. B.
`capex` ≤ 0, `rent` ≥ 0), jede Investition (`capex`, `land`, `acquisition`) hat ein Asset, und es gibt keine Zeilen außer
den deklarierten.

### 5.5 Kredite als Zustandsautomaten

- Der Zustand ist eine Liste von N-Vektoren (`B`, `A`, `i_pa`, `drawn`, `remaining`, …).
- `step()` wird für t = 0…T in der Periodenschleife aufgerufen. Es liefert die Zahlungen von t (`draw`, `interest`,
  `repay`, `fees`) und Merkzeilen (`repayment_grant`, zahlungsunwirksam).
- Liegt die **Vertragsfrequenz** über der Rasterfrequenz (monatliche Annuität, Jahresperiode), rechnet `step()`
  intern `m = payments_per_year · Δ_t` Teilschritte und summiert (Memo 01 E7, Test (f)).
- **Anschlusszins** nach Zinsbindung kommt aus `followup_rate_pa` (Konstante oder Bezug auf `market.mortgage_rate`, in der MC Prozesspfad). Die neue Rate folgt
  `refi_rule` (Memo 01 §2.4 (7)).
- **Tilgungszuschuss** mindert den Bestand am Ende von `t_TZ`, mit der Wirkung `shorten_term` oder
  `reduce_installment` (Memo 01 E9, K7).
- **`prepay()`** nimmt einen Überschuss (Ü3, standardmäßig aus) bis zur vertraglichen Obergrenze an und meldet den
  verbrauchten Betrag.
- **`amount: auto`**: Vor der Schleife bestimmt der Build aus den exogenen Zeilen der Bauphase je Lauf den
  Restbedarf nach EK und festen Krediten. Das ergibt den Zusagebetrag (N-Vektor) und einen Abrufplan proportional zum
  Bedarf. Bei Kostenüberschreitung in einem Lauf steigt also das Darlehen in diesem Lauf. Zulässig ist höchstens ein
  `auto`-Instrument je Variante.

### 5.6 Ausgleichsaktionen

Die Ketten aus `accounts$surplus_order` und `accounts$deficit_order` bestehen aus registrierten Aktionen. Je Periode
werden Überschuss `pmax(S, 0)` und Defizit `pmax(-S, 0)` *beide* durch ihre Kette geschickt. Da ein Lauf in einer
Periode nur eines von beiden hat, bleibt alles vektorisiert.

| Aktion | Rang (Memo 01) | Wirkung |
|---|---|---|
| `od_repay` | Ü1 | KK tilgen bis 0 |
| `dep_fill_reserve` | Ü2 | Guthaben bis `min_liquidity_eur` auffüllen |
| `loan_prepay` | Ü3 (optional) | Sondertilgung, Kredite absteigend nach Zins, nur wenn i_k > h, mit Puffer |
| `dep_invest` | Ü4 | Rest anlegen |
| `dep_withdraw` | D1 | Guthaben oberhalb L_min auflösen |
| `od_draw` | D2 | KK bis Limit |
| `dep_use_reserve` | D3 | Reserve angreifen, Flag |
| `equity_call` / `penalty_rate` / `stop` | D4 | Nachschuss (Zeile `equity_call`), Überziehungstranche zum Strafzins bzw. Abbruch/NA, jeweils mit Flag und Betrag |

Die letzte Defizitaktion muss unbegrenzt sein. Sonst ergänzt die Validierung `equity_call` und gibt einen Hinweis
aus. So ist der Finanzierungssaldo per Konstruktion null (I1).

### 5.7 Abhängigkeiten und Reihenfolge

Abhängigkeiten ergeben sich aus Parametern vom Typ `ref` (z. B. `of: miete`) und aus Wertbezügen (`{ref: components.x}`).
Der Build erzeugt einen gerichteten Graphen, sortiert ihn topologisch (Kahn) und meldet Zyklen mit dem Pfad als
Fehler. Exogene Komponenten dürfen nicht auf endogene Größen (Konten, Steuern) verweisen. Endogene Zahlungsregeln
(z. B. eine Ausschüttungspolitik aus dem Überschuss) werden als `account_action` umgesetzt.

### 5.8 Eingebaute Typen ohne zentrale Liste

```r
# zzz.R
.onLoad <- function(libname, pkgname) {
  ns <- asNamespace(pkgname)
  reg_reset()
  for (f in sort(ls(ns, pattern = "^typedef_"))) reg_add(get(f, envir = ns)(), source = "vofi")
  lbl_load(system.file("labels", "de", package = pkgname))
  vocab_load(system.file("vocab", package = pkgname))
}
```

Ein neuer eingebauter Typ ist **eine neue R-Datei** (`R/type-flow-pv.R` mit `typedef_pv()`), eine Label-Datei und eine
Testdatei. Keine bestehende Datei muss sich ändern. Gegen Kollationsprobleme hilft die Registrierung in `.onLoad`
(nicht auf oberster Dateiebene), dann braucht es kein `Collate`-Feld.

### 5.9 Erweiterung durch Nutzer (Beispiel in einem Skript oder Fremdpaket)

```r
vofi_register_type(vofi_type(
  name = "pv_system", kind = "flow",
  label = "Photovoltaik-Anlage",                    # in Nutzerskripten sind Literale erlaubt
  params = list(
    kwp            = vofi_param("number", min = 0, unit = "kWp", required = TRUE),
    yield_kwh_kwp  = vofi_param("number", default = 950, unit = "kWh/kWp/a", stochastic = TRUE),
    self_use_share = vofi_param("share", default = 0.3, stochastic = TRUE),
    power_price    = vofi_param("value", default = list(ref = "market.power_price"), unit = "EUR/kWh"),
    feed_in_eur_kwh = vofi_param("number", default = 0.08, unit = "EUR/kWh")
  ),
  build = function(spec, ctx) {
    op   <- ctx$by_period(ctx$grid$delta * (ctx$grid$phase == "operation"))  # Zeitvektor -> N x (T+1)
    prod <- ctx$by_sim(ctx$param(spec, "kwp") * ctx$param(spec, "yield_kwh_kwp")) * op
    own  <- prod * ctx$param(spec, "self_use_share")                         # N-Vektor: Recycling korrekt
    vofi_flows(
      vofi_row("saving", own * ctx$param(spec, "power_price", "path"), section = "project",
               category = "energy", tax_category = "imputed_benefit", label = "PV: vermiedener Strombezug"),
      vofi_row("feed_in", (prod - own) * ctx$param(spec, "feed_in_eur_kwh"), section = "project",
               category = "other_income", tax_category = "income_tax_exempt",   # § 3 Nr. 72 EStG, Memo 06
               label = "PV: Einspeisung")
    )
  },
  example = list(kwp = 10)
))
```

Danach ist `type: pv_system` in YAML und Excel nutzbar. Ein frisch erzeugtes Excel-Template enthält den Typ in der
Auswahlliste, und der Vertragstest kann auf ihn angewendet werden (`vofi_check_type("pv_system")`).

### 5.10 Steuer-Hook (abgestimmt mit Memo 06 §7)

Die fachliche Spezifikation der Schnittstelle steht in **Memo 06 §7** (Tags, Zahlungsbuch, Anlagen- und
Maßnahmenregister, Steuerzustand, Modul-API, Pflicht-Tests). Dieses Memo übernimmt sie und legt fest, wie sie in die
Registry und die Periodenschleife eingebettet wird.

**Modul-API** (S3-Generics nach Memo 06 §7.12; die Klasse des Moduls bestimmt die Methode):

```r
tax_init(module, params, assets, measures, n_sim)              # -> state (Verlustvortrag, Buchwerte, tax_due ...)
tax_step(module, t, inputs, interest, state, params)           # -> list(payment, state, report)
tax_finalize(module, T, state, terminal_inputs, params)        # -> list(payment_T, report)
# Klassen: "tax_none" (Standard, läuft in jedem Lauf), "tax_flat" (v1-L, Standard aus, für Selbstnutzer und
#          steuerbefreite Rechtsträger gesperrt), "tax_selfuse" (v1-S: § 35c-Generator, Habenzins nach Abgeltung),
#          später "tax_full_private", "tax_corporate"
```

**Einbettung in die Architektur:**

- **Registrierung:** Registry-Art `tax`. `vofi_register_tax_module(name, constructor, label = NULL, perspectives =
  NULL)` trägt einen Konstruktor ein, der ein Objekt der Modulklasse liefert. Fremdpakete (z. B. ein späteres
  `vofiTax`) registrieren in ihrem `.onLoad` und liefern S3-Methoden für `tax_init`/`tax_step`/`tax_finalize`.
  `perspectives` erzwingt die Sperren aus Memo 06 §6.
- **`inputs`** baut die Engine vor der Schleife: Aggregation der exogenen Ledger-Zeilen je **Steuerschlüssel**
  (`tax_category × asset_id × measure_id`) zu Matrizen N × (T+1) (Memo 06 §7.3). In Periode t bekommt das Modul die
  Spalte t als N-Vektoren.
- **`interest`** = `list(exo_soll, endo_soll, endo_haben)`: Zinsen der Kreditautomaten aus Periode t sowie
  KK- und Habenzinsen auf die Bestände t−1. Damit sieht das Modul auch die endogenen Zinsen, ohne dass Zirkularität
  entsteht (Memo 01 §3.4, Memo 06 §7.8).
- **Aufrufzeitpunkt** je Periode (Memo 01 §3.3, Schritt 5): nach den Kreditautomaten und den Kontozinsen, **vor
  dem Ausgleich**. Die Engine bucht `tax = −payment` (Erstattung positiv) in die Zeile `tax`. Ein Veranlagungs-Lag
  (`lag = 1`) ist Sache des Modulzustands.
- **`tax_finalize()`** liefert die am Horizont offene Steuer (Lag, offene § 35c-Tranchen, Veräußerung/Restwert). Die
  Engine bucht sie als Forderung bzw. Verbindlichkeit in den Endwert (Memo 06 §7.11) und weist sie als eigene Zeile
  aus.
- **`report`** je Periode geht als Merkzeilen (`section = "memo"`, „steuerliche Nebenrechnung“) in den Ledger.
- **`tax_none`** wird in jedem Lauf aufgerufen, damit der Codepfad getestet ist (Memo 06 §6.1 Nr. 2). Der Mehraufwand ist
  gering: Der Prototyp mit einem Pauschalmodul brauchte bei 10.000 × 81 rund 20 % mehr Laufzeit (0,30 → 0,36 s),
  das Null-Modul liegt deutlich darunter.
- **Unterlassungsalternative:** `vofi_opportunity()` verwendet dasselbe Modul (Memo 01 E11).
- **Vereinfachte Form** für Module ohne endogene Größen: `vofi_tax_module_simple(name, fun)` mit
  `fun(inputs_matrix, params)` → N × (T+1)-Zahlungsmatrix. Dokumentierte Grenze: KK- und Habenzinsen bleiben
  unberücksichtigt. Nur für Experimente gedacht, nicht für `tax_flat`.

### 5.11 Pflicht-Tags und Register (ab v1, damit das Steuermodul ohne Refactoring passt)

**Zeilenebene** (jede `vofi_row`, entspricht dem Zahlungsbuch aus Memo 06 §7.3). Pflichtfelder sind `key`, `section`,
`category`, **`tax_category`**, `cash` sowie bei Investitionen und Förderung **`asset_id`** bzw. **`measure_id`**. Die
Engine setzt `source`, `source_type` und `phase` automatisch. Optional bzw. per Default:

- USt-Trennung: `vat_rate` (Default 0), `vat_recoverable` (Default `FALSE`). `values` sind **Bruttobeträge**;
  netto und USt leitet die Engine bei Bedarf ab. Das ist v1-Pflicht nach Memo 06 §0 Nr. 4.
- `tax_period`, `spread_years`, `use_share_rented`, `program`, `activity_type`, `is_tax` (`grundsteuer`,
  `grunderwerbsteuer`, `umsatzsteuer`) und `stochastic_source` (Prozess bzw. Parameter für die Auswertung; heißt in
  Memo 06 `driver`).

**Vokabular `tax_category`** (`inst/vocab/tax_categories.yaml`): Es gelten die Codes aus **Memo 06 §7.2**, nämlich
`income_rental`, `income_other_taxable`, `income_tax_exempt`, `imputed_benefit`, `passthrough`, `expense_deductible`,
`expense_nondeductible`, `capex_depreciable`, `capex_land`, `capex_expensable`, `acquisition_ancillary`,
`subsidy_investment`, `subsidy_repayment_grant`, `subsidy_operating`, `interest_expense`, `interest_income`,
`principal`, `equity`, `disposal_proceeds`, `tax_credit`, `tax_payment`. Die Vokabulardatei enthält je Code die deutsche
Bedeutung und die zulässigen `section`-/`category`-Kombinationen (Vertragstest). Beispiele für die Zuordnung durch die
eingebauten Typen:

| Typ / Zeile | `tax_category` |
|---|---|
| `rent_path`, `modernization_levy` | `income_rental` |
| `operating_cost` (nicht umlagefähig), Verwaltung, Grundsteuer bei Leerstand | `expense_deductible` |
| umlagefähige Betriebskosten (falls brutto modelliert) | `passthrough` |
| `capex` (Neubau/Herstellung) / `capex` (Erhaltung) / `land` | `capex_depreciable` / `capex_expensable` / `capex_land` |
| Grunderwerbsteuer, Notar, Makler | `acquisition_ancillary` |
| `grant` / Tilgungszuschuss (Merkzeile, `cash = FALSE`) | `subsidy_investment` / `subsidy_repayment_grant` |
| `loan_<k>_interest`, `loan_<k>_fees`, `od_interest` | `interest_expense` |
| `dep_interest` | `interest_income` |
| `loan_<k>_draw`, `loan_<k>_repay`, `od_*`, `dep_invest`/`dep_withdraw` | `principal` |
| `equity_in`, `equity_out`, `equity_call` | `equity` |
| `energy_cost` (Selbstnutzer), `imputed_rent` | `imputed_benefit` |
| `residual_value` | `disposal_proceeds` |

**Anlagenregister** (`vofi_asset()`, Felder nach Memo 06 §7.4): `asset_id`, `asset_type` (`gebaeude_wohnen`,
`grund_boden`, `aussenanlage`, `bewegliches_wg`, `pv_anlage`, …), `in_service_period` bzw. `in_service_date`,
`construction_start_date`, `building_application_date`, `original_completion_year`, `acquisition_date`, `afa_method`,
`useful_life_override`, `land_share`. **Die Bemessungsgrundlage ist keine Eingabe.** Das Modul bildet sie aus den
`capex_depreciable`- und `acquisition_ancillary`-Zeilen mit derselben `asset_id` abzüglich `subsidy_*`. Damit werden
MC-Kostenschwankungen automatisch AfA-wirksam.

**Maßnahmenregister** (`vofi_measure()`, Memo 06 §7.5): `measure_id`, `measure_type`, `classification`
(`erhaltung` | `herstellung` | `auto`) mit `classification_source`, `completion_date`, `paid_in_full_date`,
`contractor_certified`, `funding_choice`. Diese Felder erzeugt der Expander `measures` aus dem Domänenblock (4.9).

**Projektebene:** `project$perspective` (Steuerregime nach Memo 06 §7.1 Nr. 4), Regime-Flags für Wohnungsunternehmen
(steuerbefreite Vermietungsgenossenschaft, gemeinnützig), Selbstnutzungsanteil je Wohnungsgruppe.

**Test „Steuerbereitschaft“** (ergänzt die Pflicht-Tests aus Memo 06 §7.12): Für alle Beispielszenarien hat jede
zahlungswirksame Zeile eine gültige `tax_category`. Jede `capex_*`-, `acquisition_ancillary`- und `subsidy_*`-Zeile
verweist auf ein vorhandenes Asset bzw. eine vorhandene Maßnahme. `tax_none` ergibt einen VoFi, der mit dem
Vor-Steuer-VoFi identisch ist.

### 5.12 Typkatalog (Vorschlag)

| Art | v1 | später |
|---|---|---|
| `flow` | `capex`, `land`, `rent_path`, `modernization_levy`, `operating_cost`, `maintenance`, `replacement`, `energy_cost`, `co2_cost`, `grant`, `imputed_rent`, `residual_value`, `share_of`, `custom_series`, `equity_flows` (Einlagen/Entnahmen) | `pv_system`, `rent_binding` (Belegungsbindung), `vacancy_ramp`, `sale_partial` |
| `instrument` | `annuity_loan`, `installment_loan`, `bullet_loan` (jeweils mit Teilvalutierung, tilgungsfreien Jahren, Zinsbindung, Tilgungszuschuss, Disagio, Bereitstellungsprovision) | `bauspar`, `forward_loan`, `variable_rate_loan`, `member_shares` (Genossenschaftsanteile) |
| `account_action` | `od_repay`, `dep_fill_reserve`, `dep_invest`, `dep_withdraw`, `od_draw`, `dep_use_reserve`, `equity_call`, `penalty_rate`, `stop` | `loan_prepay` (Ü3, Code in v1, Standard aus), `payout_policy` |
| `distribution` | nach Memo 04 E3: `fixed`, `normal`, `truncnorm`, `lognormal`, `uniform`, `triangular`, `pert`, `bernoulli`, `discrete`, `empirical`; zusätzlich `beta` | `mixture` |
| `process` | nach Memo 04 E3: `ar1`, `linked_ar1`, `vasicek`, `mr_trend`, `gbm`, `scenario_mix` (z. B. CO2-Pfade mit Gewichten), `iid`, `fixed_path` (Stresstests) | `bootstrap` aus historischen Reihen (Memo 04 §10.2), Regimewechsel |
| `kpi` | Memo 01 §4 (EW, ΔEW, R1–R3, Amortisation, Liquidität, max. KK, Nachschüsse), DSCR/ICR/LTV (WU) | Entnahme-Äquivalent als Standard-KPI in MC |
| `tax` | `tax_none` (Standard); nach Memo 06 §6 zusätzlich `tax_flat` (Referenzmodul, Standard aus, gesperrt für Selbstnutzer und steuerbefreite Rechtsträger) und `tax_selfuse` (§ 35c-Generator mit BEG-Ausschluss, Habenzins nach Abgeltungsteuer) | `tax_full_private`, `tax_corporate` |
| `expander` | `measures`, `unit_groups`, `funding`, `energy`, `residual` | `legal_reforms` |

---

## 6. Kern-Engine

### 6.1 Zeitraster

```r
vofi_time_grid(valuation_date, horizon_years, construction_months = 0L,
               construction_step = c("month", "quarter"), operation_step = "year",
               horizon_from = c("completion", "valuation"))
```

Ergebnis ist ein Data Frame mit einer Zeile je Zeitpunkt t = 0…T: `t`, `delta` (Δ_t in Jahren, Δ_0 = 0), `tau`
(kumuliert), `date_end`, `phase`, `op_year` (Betriebsjahr) und `label` („03/2027“, „2028“). Das Raster folgt Memo 01 E7
(Vektor der Periodenlängen). Alle Typen müssen Zinsen und Jahresbeträge über die Raster-Helfer umrechnen
(Vertragspunkt, im Vertragstest mit einem Monats-/Jahresraster geprüft). So rechnet ein Typ auf beiden Rastern
richtig. Komponenten dürfen intern feiner rechnen (`ctx$grid$fine("month")`, z. B. für den Mietpfad mit 15-Monats-
Wartefrist nach Memo 02) und mit `ctx$grid$aggregate()` auf das VoFi-Raster summieren. Kosten: eine Matrix
10.000 × 360 Monate ≈ 29 MB.

### 6.2 Stufen eines Laufs

```text
vofi_run(model, n_sim, seed)
 └─ für jeden Chunk (Vielfaches von 1.000 Läufen):
     1  smp_draw(model$sampler, block_ids, seed)      Ziehungen je Schlüssel (U, Z), Copula/LHS
     2  ctx <- eng_context(model, draws)              Raster, param()/market()-Auflösung
     3  exo <- eng_flows(model, ctx)                  flow-Typen in Topo-Reihenfolge → Ledger (exogen)
     4  eng_auto_amounts(model, ctx, exo)             Zusagebeträge für amount: auto
     5  core <- eng_balance(model, ctx, exo)          Periodenschleife: Kredite, Zinsen, Steuer, Ausgleich
     6  eng_checks(core)                              Invarianten I1–I3 (Laufzeitprüfung)
     7  kpi <- kpi_compute(model$kpis, core, ctx)     Kennzahlen (+ Unterlassungsalternative mit gleichen Ziehungen)
     8  eng_store(core, kpi, store)                   Speicherstrategie (Bänder im Streaming)
 └─ Chunks zusammenführen → vofi_result (N = 1) bzw. vofi_mc_result
```

### 6.3 Sampling und Zufallszahlen

Die fachliche Spezifikation (Verteilungen, Prozesse, Kalibrierung, Konvergenz, Sensitivität) steht in Memo 04. Hier
geht es um die Einbettung in die Architektur.

- **Trennung**: Der Sampler-Plan (im Build aus dem Overlay `stochastic` erzeugt) listet alle stochastischen
  *Schlüssel* (Namen der Overlay-Einträge, z. B. `par:huelle_kosten`, `shock:mortgage_rate`) mit Ziel­pfad und
  Verteilung bzw. Prozess. Typen ziehen nie selbst.
- **Uniforms zuerst**: Statische Größen entstehen aus Uniforms über die Quantilfunktion der Verteilung. Deshalb muss
  jede Verteilung `quantile()` implementieren. LHS, Iman-Conover und gemeinsame Zufallszahlen funktionieren dann
  einheitlich. Prozesse bekommen Standardnormal-Schocks Z (N × T).
- **Benannte Ströme mit Blöcken**: Seed nach Memo 04 §4.3, `seed_j = (seed · 1000003 + h(name_j)) mod (2³¹ − 1)` mit
  Polynom-Hash h. Ergänzt wird der Blockindex im Namen (`par:<name>:<b>`), RNG-Block b = 1.000 Läufe. **Ein Block ist
  zugleich ein LHS-Replikat** (Memo 04 E6: bei N = 10.000 also 10 Replikate). Folgen:
  1. **CRN über Varianten**: Gleicher Schlüssel ergibt in allen Varianten dieselbe Ziehung (im Prototyp geprüft:
     identische Baukosten-Ziehung, obwohl die Variante eine Komponente und einen Kredit weniger hat).
  2. **Stabilität**: Ein neuer stochastischer Parameter verschiebt keine anderen Ziehungen.
  3. **Unabhängigkeit von Chunk-Größe und Worker-Zahl**: Chunks sind Vielfache der Blockgröße.
  4. **Einzellauf reproduzierbar**: `vofi_sim(mc, i)` rechnet Block ⌈i/1000⌉ neu und liefert die vollständige VoFi-Tabelle
     von Lauf i, z. B. für das 5-%-Quantil („Wie sieht der schlechte Fall aus?“; Memo 04 E10: P5/P50/P95).
  5. **Erhöhung von N um ganze Blöcke** lässt die bisherigen Läufe unverändert (Memo 04 hält fest, dass sich bei LHS mit
     fester Replikatzahl die Ziehungen mit N ändern; mit fester Blockgröße gilt das nur innerhalb eines Blocks).
- **LHS** je Block und Schlüssel: `u = (sample.int(n) - runif(n)) / n`. Rangkorrelationen zwischen statischen Größen nach
  **Iman-Conover** je Replikat (erhält die LHS-Schichtung exakt; Memo 04 E5/E6). Korrelierte Prozessschocks über
  **Cholesky** je Periode, nicht positiv definite Matrizen werden per Eigenwert-Clipping repariert (mit Warnung).
  Beides ist Base R, ohne `lhs`/`mvtnorm`/`Matrix`.
- **RNG-Hygiene**: `RNGkind("Mersenne-Twister", "Inversion", "Rejection")` lokal setzen, danach `.Random.seed` und
  `RNGkind` des Nutzers wiederherstellen (eigene `with_local_seed()`, ohne withr in Imports). Das Paket setzt nie
  `future::plan()`, sondern respektiert den Plan des Nutzers.
- **Deterministischer Lauf**: Der Sampler liefert die Basiswerte (`point()`) bzw. erwarteten Pfade (`expected()`).
  N = 1 ist derselbe Codepfad.
- **Gespeicherte Eingaben**: Statische Ziehungen (N × K) bleiben im MC-Ergebnis für die globale Sensitivität (Memo 04
  §7.4). Für Prozesse werden Pfadmerkmale gespeichert (mittleres Wachstum, Endniveau, Szenarioindex bei
  `scenario_mix`).

### 6.4 Ledger

```r
ledger <- list(
  rows = data.frame(              # eine Zeile je Ledger-Zeile
    key, section, category, tax_category, cash, kind,   # kind: flow | stock | memo | check
    asset_id, measure_id, vat_rate, source, source_type, order, label_key),
  values = list(<key> = matrix(N, T + 1), ...)      # Spalten = Zeitpunkte 0..T
)
```

- **Orientierung N × (T+1)**: R speichert spaltenweise. Die Spalte `m[, t]` liegt zusammenhängend im Speicher und ist
  der Zugriff in der Periodenschleife.
- **Benannte Liste statt 3D-Array**: Typen liefern Zeilen unabhängig voneinander, Zeilen kommen ohne Umkopieren hinzu,
  das Summieren über `Reduce("+", …)` ist einfach.
- **Reihenfolge** der Abschnitte für die Grob-Tabelle: `project` (100) → `grants` (200) → `equity` (300) → `loans`
  (400 + k) → `overdraft` (500) → `deposit` (600) → `tax` (700) → `check` (800) → `stocks` (900) → `memo` (950).
- **Fallen bei N = 1 und beim Recycling**: Einzelzeilen immer mit `m[i, , drop = FALSE]` herausgreifen. Zeitvektoren
  nur über `ctx$by_period()` mit Matrizen verknüpfen (geprüft: `matrix(1, 4, 4) * 1:4` skaliert Zeilen statt Spalten, ohne
  Warnung). Die Tests laufen mit N = 1, N = 2 und N = T+1.

### 6.5 Periodenschleife (R-Skizze)

```r
eng_balance <- function(model, ctx, exo) {
  T1  <- ctx$T + 1L
  acc <- acc_init(model$accounts, ctx)                 # G, KK, Limits, L_min, Raten je Periode
  ist <- lapply(model$instruments, function(k) k$type$init(k$spec, ctx))
  tax  <- model$tax                                    # Modulobjekt, Standard: Klasse "tax_none"
  tin  <- tax_inputs(exo, ctx)                         # Steuerschlüssel tax_category x asset_id x measure_id
  tst  <- tax_init(tax, model$tax_params, ctx$assets, ctx$measures, ctx$n)
  rec  <- rec_alloc(model, ctx)                        # vorallokierte N x (T+1)-Matrizen
  for (j in seq_len(T1)) {                             # j = t + 1
    F <- exo$sum[, j]                                  # originär, Zuschüsse, geplante EK-Ströme
    for (k in names(ist)) {                            # (2) Kreditautomaten
      r <- model$instruments[[k]]$type$step(ist[[k]], j - 1L, ctx)
      ist[[k]] <- r$state
      F <- F + rec_flows(rec, k, j, r$flows)
      rec_memo(rec, k, j, r$memo)
    }
    hz <- acc$G  * acc$h[, j]                          # (3) Zinsen auf Vorperiodenbestände
    kz <- acc$KK * acc$s[, j]
    S  <- F + hz - kz                                  # (4) vorläufiger Saldo
    r <- tax_step(tax, j - 1L, inputs = tax_slice(tin, j),   # (5) Steuer-Slot (tax_none: payment = 0)
                  interest = list(exo_soll = rec_loan_interest(rec, j), endo_soll = kz, endo_haben = hz),
                  state = tst, params = model$tax_params)
    tst <- r$state
    S   <- S - r$payment                               # Zahlung positiv, Erstattung negativ (Memo 06)
    rec_tax(rec, j, r)
    sur <- pmax(S, 0)                                  # (6) Ausgleich
    def <- pmax(-S, 0)
    for (a in model$surplus_chain) {
      r <- a$apply(acc, sur, j, ctx, ist)
      acc <- r$acc; ist <- r$ist %||% ist; sur <- sur - r$used
      rec_action(rec, a, j, r)
    }
    for (a in model$deficit_chain) {
      r <- a$apply(acc, def, j, ctx, ist)
      acc <- r$acc; def <- def - r$used
      rec_action(rec, a, j, r)
    }
    rec_interest(rec, j, hz, kz)                       # (7) Bestände und Merkzeilen
    rec_stocks(rec, j, acc, ist)
  }
  fin <- tax_finalize(tax, ctx$T, tst, rec_terminal(rec), model$tax_params)   # offene Steuer am Horizont
  rec_finish(rec, fin)                                 # (8) BS, balance_check, Flags
}
```

Etwa 60 Zeilen fachlich lesbarer Kern. Der gemessene Prototyp (Anhang A) folgt diesem Ablauf.

### 6.6 Unterlassungsalternative und Vergleich

- `vofi_opportunity(model)` baut ein Modell mit denselben EK-Strömen (inkl. endogener Nachschüsse aus der Investition,
  Memo 01 K11), denselben Konten, Ketten und Steuermodul, ohne Investition und ohne Kredite. Es wird mit **denselben
  Ziehungen** gerechnet (stochastische Habenzinsen).
- `vofi_compare()` rechnet jede Alternative als **vollständigen VoFi** und vergleicht über ΔEW (Memo 01 E6). Der
  zeilenweise **Differenz-VoFi** dient nur der Erklärung. `comparison_mode: differential` (Memo 02 §1.1) wird als
  ausdrücklich gekennzeichneter Vereinfachungsmodus unterstützt (Zahlungen Mit − Ohne in einem VoFi), mit Hinweis im
  Bericht.
- Weil die Ziehungen gemeinsam sind (CRN), ist die Verteilung der Differenz ΔEW_A − ΔEW_B je Lauf aussagekräftig:
  P(A besser als B), Quantile der Differenz.

### 6.7 Kennzahlen (KPI-Registry)

Eine KPI ist `compute(core, ctx)` → N-Vektor (+ Attribut `na_reason`). Standard-Set nach Memo 01 §4:
`terminal_value`, `terminal_value_opp`, `delta_terminal_value`, Varianten **mit und ohne Restwert** (Memo 01 E12),
`roe_classic`, `roe_mirr` (R3, Standard), `roe_irr` (R2, ergänzend), `payback_time` (Memo 01 §4.5, in Jahren über
`tau`), `min_net_liquidity`, `max_overdraft`, `sum_equity_calls`, `flag_limit_breach`, `dscr_min`, `icr_min`, `ltv_max`
(WU), später `withdrawal_equivalent`. Renditen per vektorisierter Bisektion mit Horner-Schema (gemessen 28 ms bei
10.000 × 81, Genauigkeit 1e-11). Für EK_0 = 0 oder EW ≤ 0 gilt `NA` mit Begründungscode (Memo 01 E5). MC-Statistiken:
Mittelwert, MC-Standardfehler, Quantile (5/10/25/50/75/90/95 %), P(ΔEW < 0), Expected Shortfall 5 %, NA-Anteil,
P(Limitverletzung).

### 6.8 Laufzeit-Invarianten (immer aktiv, billig)

- I1: `max(abs(balance_check)) <= tol` mit `tol = 1e-8 * max(1, Volumen)`. Sonst `vofi_error_engine` mit Lauf, Periode
  und den größten Zeilenbeiträgen.
- Keine `NA`/`Inf` in Zeilen. Bestände ≥ 0. Bei L_min = 0 gilt G · KK = 0 (I3).
- Ergebnisfeld `checks` mit der maximalen Abweichung je Invariante (erscheint in Excel und Bericht als Blatt bzw.
  Abschnitt „Prüfungen“).

### 6.9 Speicherstrategie `store` (abgestimmt mit Memo 04 E10, §5.5)

| Wert | Speichert | Speicher bei 10.000 × 81 |
|---|---|---|
| `full` | alle Zeilen aller Läufe | ≈ 6,5 MB je Zeile (gemessen: 29 Zeilen = 179 MiB; 36 Zeilen ≈ 233 MB) |
| `bands` (MC-Standard) | KPIs und Pfadmerkmale aller Läufe, statische Ziehungen, **Fächerbänder im Streaming** (je Periode `quantile()` auf den N-Vektor ausgewählter Zeilen, z. B. `net_position`, `dep_balance`, `od_balance`, Kapitaldienst; 28 ms je Zeile), vollständige VoFi-Tabellen für `keep_runs` (z. B. `p05`, `p50`, `p95`) per zweitem Durchgang über `vofi_sim()` | ≈ 10–20 MB |
| `kpi` | nur KPIs, Pfadmerkmale und Ziehungen | < 10 MB |
| `auto` | `full` bei N = 1, sonst `bands` | – |

Vor dem Lauf wird der Speicherbedarf geschätzt (Zeilen × N × (T+1) × 8 Byte). Über `getOption("vofi.max_memory_gb",
2)` gibt es eine Warnung mit Vorschlag (`store = "bands"`). Weil Quantile über Chunks nicht exakt zusammenführbar
sind, werden die Bänder bei mehreren Chunks aus 1–2 gespeicherten N × (T+1)-Matrizen der Bandzeilen gebildet
(Memo 04 §5.5). Diese Matrizen werden nach der Bandbildung verworfen.

### 6.10 Ergebnisklassen und Methoden

| Klasse | Inhalt (Felder) | Methoden |
|---|---|---|
| `vofi_scenario` | kanonische Liste, `source`, Herkunft | `print` (Übersicht deutsch), `summary` |
| `vofi_spec` | aufgelöste Variante (Komponentenebene), `provenance` | `print`, `as.data.frame` (Parameterliste mit Herkunft) |
| `vofi_model` | `spec`, `grid`, `nodes`, `instruments`, `sampler`, `surplus_chain`, `deficit_chain`, `tax`, `kpis`, `hash` | `print` |
| `vofi_validation` | Befunde | `print`, `as.data.frame`, `format` |
| `vofi_result` | `spec`, `grid`, `ledger`, `kpis` (Liste), `checks`, `flags`, `opportunity` (Kurzledger), `meta` (Version, Schema, Seed, Laufzeit, Bibliotheksstände) | `print` (Kopf-KPIs + gekürzte VoFi-Tabelle), `summary`, `format` (Zeichenmatrix im deutschen Zahlenformat), `plot`, `as.data.frame` (lang oder `wide = TRUE`) |
| `vofi_mc_result` | `kpis` (Data Frame N Zeilen, inkl. Pfadmerkmale), `inputs` (Ziehungen), `bands` (Quantile je Periode), `runs` (vollständige `vofi_result` für `keep_runs`), `deterministic` (`vofi_result`), `stats` (inkl. Standardfehler aus Replikaten), `checks`, `meta` (seed, n_sim, rng_block, sampling, replicates, reparierte Korrelationsmatrizen) | `print` (MC-Kennzahlen mit SE und Quantilen, Vergleich zum deterministischen Wert), `summary`, `format`, `plot` (`verteilung`, `fan`, `cdf`, `konvergenz`, `streu`, `tornado`), `as.data.frame` (`what = "kpis"`/`"paths"`), `quantile` |
| `vofi_comparison` | `results` (benannt), `baseline`, `differences`, `ranking`, `crn = TRUE`, Vergleichbarkeitsbefund | `print` (KPI-Tabelle nebeneinander), `summary`, `format`, `plot` (`endwert`, `differenz`, `cdf`, `bestand`), `as.data.frame` |
| `vofi_sensitivity` | Methode, Parameter, Ausschläge, KPI-Werte | `print`, `plot` (Tornado/Spider), `as.data.frame` |
| `vofi_table` | Data Frame im Grob-Layout + Formatierungsinfo | `print`, `format` |

---

## 7. Reporting (Scope v1)

**Zwei Berichtsmodi** (Memo 07 §0 Nr. 1, §5): `report_mode = "expert"` (**Fachmodus** für Wohnungsunternehmen und
Genossenschaften: VoFi-Tabelle, EK-Rendite, DSCR, Werte je m² Wohnfläche) und `report_mode = "household"`
(**Haushaltsmodus** für Selbstnutzer und Kleinvermieter: monatliche Belastung, Ersparnis je Monat, Amortisationsjahr,
Ampel). Beide nutzen dasselbe Ergebnisobjekt. Der Modus wählt nur KPI-Set, Vorlage und Grafiken (Standard aus der
Perspektive, überschreibbar). Die **Nutzerkostensicht** (Warmmiete je Variante, Memo 07 A-20) ist eine abgeleitete
Tabelle aus den getaggten Zeilen (`vofi_tenant_view()`, v1).

| Ausgabe | v1 | v1.1 | v2 |
|---|---|---|---|
| Konsole | `print`/`summary`/`format`, `vofi_table()` im Grob-Layout und transponiert (ab 15 Perioden, Memo 01 §2.3), deutsches Zahlenformat (`1.234.567`, `3,80 %`, `25.10.2026`) | `vofi_explain(x, row)`: Herkunft, Typ, Parameter, Formel | – |
| Excel (`vofi_export_excel`, openxlsx) | Blätter: Übersicht, VoFi, VoFi transponiert, Kennzahlen, Annahmen (alle Parameter mit Herkunft), Prüfungen; bei MC zusätzlich MC-Statistik, Läufe (KPIs je Lauf), Pfad-Quantile; bei Vergleich Varianten. Feste Kopfzeilen, Zahlenformate, negative Werte rot. **Finanzierungssaldo als Excel-Formel `=SUM(...)`** über die Spalte, damit Controller die Nullsumme selbst sehen | Blatt „Rechenweg“ mit Live-Formeln für Konten (deterministisch), zugleich unabhängiges Orakel | Corporate-Design-Vorlagen |
| Grafiken (ggplot2, Suggests) | Bestandssaldo (deterministisch) bzw. Fan-Chart 5–95/25–75/Median; gestapelte Zahlungsblöcke je Periode; Verteilung von EW/ΔEW mit Quantilen und P(ΔEW < 0); Verteilungsfunktion (Varianten); Konvergenz (laufender Mittelwert ± 95 %-KI); Tornado; Streudiagramm Eingabe vs. ΔEW; Varianten-Boxplot. Okabe-Ito-Palette, deutsche Achsen, `linewidth` statt `size` (läuft mit ggplot2 3.4 und 4.x) | Wasserfall: Beiträge der Zahlungsblöcke zum Endwert | interaktiv (plotly) |
| Bericht (`vofi_report`, rmarkdown, Suggests) | HTML (self-contained) und DOCX (pandoc 3.1.3 vorhanden): Deckblatt, Zusammenfassung, Annahmen mit Quellen und Stand, VoFi-Tabelle, Kennzahlen, Grafiken, MC, Varianten, **Pflichtsensitivitäten** (Restwert = 0, Variation von h; Memo 01 §11), Methodik und Grenzen, Prüfungen | Vorlagenparameter (Logo, Farben) | PDF (braucht LaTeX), Quarto |
| Shiny (`vofi_app`, Suggests) | – (nur Stub, der auf v1.1 verweist) | **Viewer**: Szenario laden (YAML/Excel), Validierungsbericht, Kernparameter-Regler (aus Parameterschema generiert), deterministisch + MC bis 10.000, VoFi-Tabelle (DT), Kennzahlen, Grafiken, Variantenvergleich, Downloads (Excel/HTML). Module `mod_load`, `mod_params`, `mod_results`, `mod_mc`, `mod_compare`. Gesamte Logik über die Paket-API | Szenario-Editor (Komponenten anlegen), Mehrbenutzerbetrieb |

**Begründung für Shiny in v1.1:** Die App ist nur eine dünne Schicht über der API. Solange sich API und
Parameterschemata ändern, entsteht Doppelarbeit. Tests über `shiny::testServer()` (shinytest2 fehlt). Optional ein
Screenshot-Rauchtest mit dem vorhandenen Chromium/Playwright außerhalb von `R CMD check`.

**Berichtstechnik:** `rmarkdown::render()` mit `params = list(result = x)`, `envir = new.env()`, `intermediates_dir =
tempdir()`. Die Vorlage liegt unter `inst/templates/report/`. Die Texte stehen in der Vorlage (Rmd darf UTF-8
enthalten) bzw. im Label-Katalog.

---

## 8. Teststrategie

**Grundsätze:** testthat 3. Edition, eine Testdatei je R-Datei, Fixtures unter `tests/testthat/fixtures/`, keine
Netzwerkzugriffe, Schreiben nur in `withr::local_tempfile()`, feste Seeds.

| Ebene | Inhalt | Werkzeug |
|---|---|---|
| 1 Vertragstests | Für **jeden registrierten Typ** automatisch (`test-contract-types.R` iteriert über `vofi_types()`): `example` bauen mit N = 1, 2, 7; Dimensionen, Tags, Vorzeichen, Labels vorhanden; **Vektorisierungsinvarianz** (Lauf i im Batch = Einzellauf mit den Ziehungen von i); Rasterinvarianz (Jahresraster vs. Monatsraster mit gleichen Jahresbeträgen ergibt plausible Aggregate); Verteilungen: `quantile(c(0, 0.5, 1))` im Träger, `moments()` gegen Stichprobe | `expect_vofi_flows_contract()`, `make_ctx()` |
| 2 Orakel | **Memo 01 Beispiele (a) bis (f)** inkl. (a3), (b1), (b2), (c1), (c2), (e) und Test (f): Toleranz 1e-6 gegen die ungerundeten Skriptwerte (CSV aus dem Python-Referenzskript in Memo 01 §10.8), 0,005 gegen die Tabellenwerte. **Memo 02 Rechenbeispiele 1–7** für Mietrecht, Förderung und CO2-Aufteilung als Regelorakel. **Memo 07 Referenzszenarien S1–S5** als Integrationsszenarien (`inst/extdata/examples/s1_…`–`s5_…`) mit den deterministischen Prüfwerten S*-T* (Förderbeträge, Kappungen, Annuitäten, Restschulden) und dem Testkatalog aus Memo 07 §6.2. **Pflicht-Tests der Steuerschnittstelle** aus Memo 06 §7.12 (u. a. `tax_none` und `tax_flat` mit s = 0 ergeben den Vor-Steuer-VoFi, Standardmodell-Test, AfA-Summe = Bemessungsgrundlage, Chunk-Invarianz). Geschlossene Formeln: Annuität, Restschuld, reine Anlage EW = EK·Π(1+h), Rentenendwert | `test-oracles.R`, `fixtures/oracles/` |
| 3 Invarianten | **I1–I6** (Memo 01 §3.5) für alle Beispielszenarien, deterministisch und für **alle** Läufe einer MC mit N = 2.000: Finanzierungssaldo = 0, Vermögensfortschreibung (I2), Nichtnegativität und Komplementarität (I3), vollkommener Kapitalmarkt (I4), Monotonie bei Zusatzentnahme (I5), Unterlassung (I6) | `test-invariants.R` |
| 4 Differenztests | **Skalare Referenz-Engine** (ca. 150 Zeilen, einfache Schleifen je Lauf und Periode, von einem *anderen* Agenten geschrieben) gegen die vektorisierte Engine auf 200 zufällig erzeugten Szenarien (Generator mit festen Seeds) | `helper-reference-engine.R` |
| 5 Metamorphe Tests | Skalierung aller Geldbeträge mit k skaliert EW mit k; Komponente mit Betrag 0 ändert nichts; höhere Miete ⇒ EW ≥; höherer KK-Zins ⇒ EW ≤; eine Variante mit nur geändertem Label ergibt identische Ergebnisse; zusätzliche, unbeteiligte stochastische Größe lässt die übrigen Ziehungen unverändert (CRN) | `test-metamorphic.R` |
| 6 MC-Statistik | MC mit entarteten Verteilungen (min = mode = max) = deterministischer Lauf; Mittelwert lognormaler Parameter innerhalb 4 SE vom theoretischen Wert; LHS: genau eine Ziehung je Schicht; Iman-Conover: Ziel-Rangkorrelation ±0,03 (N = 5.000); Gauß-Copula-Schocks: Korrelation über Fisher-z-Test; linearer Fall ohne Ausgleichsnichtlinearität: E[EW] = EW(E[X]) innerhalb 4 SE; Reproduzierbarkeit: gleicher Seed ⇒ identisch; Chunk-Größe 1.000 vs. 10.000 und sequenziell vs. `future` ⇒ identisch; `vofi_sim(mc, i)` = Zeile i | `test-mc-statistics.R` |
| 7 Eingabe | YAML-Handler (Tabelle 4.5), Deep-Merge, `~`-Löschen, `from:`-Ketten und Zyklen, Varianten-Ketten, Expander, Excel-Round-Trip (YAML → XLSX → Liste identisch), Vorlage = frisch generierte Vorlage, jede Validierungsmeldung mindestens einmal ausgelöst (Klasse `vofi_error_validation`) | `test-io-*.R`, `test-scenario-*.R`, `test-validate-*.R` |
| 8 Snapshots | `print`/`format` aller Ergebnisklassen, Validierungsbericht, VoFi-Tabelle, Fehlermeldungen (deutsch); Excel-Export: zurücklesen und Werte vergleichen (keine binären Snapshots, xlsx enthält Zeitstempel); JSON-Schema; Grafiken nur wenige `vdiffr`-Snapshots mit `skip_on_ci()`/`skip_on_cran()`, weil sich SVGs zwischen ggplot2-Versionen ändern | `expect_snapshot()`, `local_reproducible_output(width = 100)` |
| 9 Performance | Regressionstest mit großzügiger Schwelle (10.000 × 53 < 3 s), `skip_on_cran()`; Benchmarks in `bench/` | `bench::mark` |
| 10 App | `shiny::testServer()` für Modul-Logik (v1.1) | – |

**Abdeckung:** ≥ 90 % Zeilenabdeckung für `engine-*`, `sampling*`, `dist-*`, `process-*`, `scenario-*`, `values`,
`validate-*`, `type-*`, `kpi-*`; ≥ 80 % gesamt (`covr::package_coverage()`). App und Berichtsvorlage ausgenommen.

**`R CMD check`-Sauberkeit:** 0 Errors, 0 Warnings, 0 Notes (`--as-cran` soweit offline möglich). Dazu gehören
ASCII-R-Code, `LANG=C.UTF-8`, Suggests nur über `requireNamespace()` mit deutscher Meldung, Beispiele unter 5 s
(`n_sim = 200`), `@examplesIf interactive()` für App und Berichte, Vignetten zusammen unter 60 s (MC mit 1.000
Läufen), `utils::globalVariables()` für ggplot2-Spaltennamen, keine globalen Seiteneffekte (RNG, Optionen,
Arbeitsverzeichnis), `lintr` ohne Befund (`.lintr`: Zeilenlänge 100, `object_name_linter("snake_case")`).

---

## 9. Performance: Ziele und Messungen

| Vorgang | Ziel v1 | Prototyp (Abschnitt 2.5) | Reserve |
|---|---|---|---|
| Szenario lesen, auflösen, validieren, bauen (30 Komponenten) | < 0,3 s | – (YAML-/Excel-Lesen im Millisekundenbereich) | – |
| Deterministischer Lauf (bis 83 Perioden) | < 50 ms Kern, < 0,5 s inkl. Lesen | 2–11 ms | ≈ 5× |
| MC 10.000 × 50–53 Perioden inkl. KPIs, Unterlassung, Quantilbänder | **< 1,5 s** | 0,12–0,25 s (+ KPIs ≈ 0,05 s) | ≈ 5× |
| MC 10.000 × 80–83 Perioden | **< 3 s** | 0,30–0,50 s | ≈ 6× |
| Variantenvergleich 5 × 10.000 × 53 (CRN) | < 8 s | ≈ 1,5 s (hochgerechnet) | ≈ 5× |
| Tornado 20 Parameter × 2 (deterministisch) | < 1 s | ≈ 0,1–0,2 s (hochgerechnet) | – |
| Break-even per `uniroot` (≈ 15 Läufe) | < 0,5 s | ≈ 0,15 s | – |
| 100.000 Läufe × 53 | < 20 s sequenziell | 2,1 s (P1, T = 40) | – |
| Spitzenspeicher MC 10.000 × 83, `store = "bands"` | < 1 GB | ≈ 0,4 GB (gc-Trigger) | – |
| Shiny: Reaktion auf Reglerbewegung (deterministisch) | < 0,3 s | – | – |

**Leitlinien:** keine Funktionsaufrufe je Lauf (nur je Periode, Komponente oder Chunk); `apply()` über Zeilen vermeiden,
stattdessen spaltenweise Schleifen über t (`col_cumprod` war im Test schneller als `apply(…, 1, cumprod)`); Matrizen
vorallokieren; Zufallszahlen nur für benutzte Prozesse ziehen; Byte-Compiler eingeschaltet lassen; Parallelisierung
(`parallel = TRUE`, `future.apply`) nur ab etwa 10⁶ Läufen oder bei sehr teuren Modellen anbieten, standardmäßig aus.

---

## 10. Abhängigkeiten

| Paket | Rolle | Feld | Begründung |
|---|---|---|---|
| `yaml` | Szenarien und Bibliothek | Imports | 0 Abhängigkeiten. Eigene Handler für deutsche Zahlen |
| `openxlsx` | Excel lesen, schreiben, Vorlage | Imports | Praktiker-Eingabe ist Kernfunktion. Rekursiv: Rcpp, stringi, zip, cli. Kapselung in `io-excel-*.R` und `report-excel.R`, damit ein Wechsel zu `openxlsx2` (aktiv entwickelt, nicht installiert) lokal bleibt |
| `stats`, `utils`, `tools` | Quantilfunktionen, `uniroot`, `adist`, Dateiendungen | Imports | Base R |
| `ggplot2` | Grafiken | Suggests | Vorgabe des Auftrags. Mit `requireNamespace()` geprüft |
| `rmarkdown`, `knitr` | Bericht, Vignetten | Suggests | `VignetteBuilder: knitr` |
| `shiny`, `bslib`, `DT` | App (v1.1) | Suggests | – |
| `future`, `future.apply` | optionale Parallelisierung | Suggests | Plan setzt der Nutzer |
| `jsonlite` | JSON-Schema-Export, optional JSON-Szenarien | Suggests | – |
| `testthat (>= 3.0.0)`, `withr`, `vdiffr` | Tests | Suggests | – |
| **nicht verwendet** | `R6`, `dplyr`/`tidyr`/`purrr`/`tibble`, `data.table`, `checkmate` (Meldungen englisch), `cli`/`rlang` direkt, `Matrix`, `readxl` (openxlsx liest), `lhs`/`mvtnorm` (eigene Umsetzung), `jsonvalidate`/`V8`, `glue` | – | Abschnitt 2, 4.11, 6.3 |

Footprint der Installation (Imports, rekursiv): **6 Fremdpakete** (yaml, openxlsx, Rcpp, stringi, zip, cli; davon cli
ohnehin über openxlsx). Zum Vergleich: ggplot2 bringt 16, shiny 29, rmarkdown 24 Pakete mit (aktuelle CRAN-Angaben,
25.10.2026).

---

## 11. Modulkarte (Datei für Datei) und exportierte API

### 11.1 Dateien und Verantwortlichkeiten

WS = Arbeitspaket aus Abschnitt 12. **I** = Integrator (gemeinsame Dateien).

| Datei | Verantwortung | Exporte | WS |
|---|---|---|---|
| `R/vofi-package.R` | Paketdoku, `globalVariables` | – | I |
| `R/zzz.R` | `.onLoad`: Registry, Labels, Vokabulare, Optionen | – | I |
| `R/contracts.R` | Konstruktoren und Validatoren aller Kernobjekte (`new_vofi_result()`, `validate_vofi_flows()` …), Feldlisten | `vofi_row`, `vofi_flows`, `vofi_asset` | I |
| `R/registry.R` | Registry-Umgebung, Registrierung, Abfrage, Prüfung | `vofi_type`, `vofi_register_type`, `vofi_types`, `vofi_type_info`, `vofi_check_type` | I |
| `R/vocab.R`, `R/labels.R`, `R/conditions.R` | Vokabulare, Label-Katalog (`lbl()`, `msg()`), Bedingungsklassen (`vofi_abort()`) | – | I |
| `R/utils-merge.R`, `R/utils-path.R`, `R/utils-format.R`, `R/utils-hash.R`, `R/utils-seed.R` | Deep-Merge, Pfadoperationen, deutsches Zahlenformat, stabile Hashfunktion, lokale Seeds | – | I (Phase 0) |
| `R/time-grid.R` | Raster, Raten- und Periodenhelfer, Aggregation | `vofi_time_grid` | WS-D |
| `R/values.R` | Normalisierung der Wertangaben, `param()`-Auflösung | – | WS-D |
| `R/expr.R` | sicherer Ausdrucksauswerter | – | WS-B |
| `R/schema.R` | Parameter-DSL, JSON-Schema-Export | `vofi_param`, `vofi_json_schema` | WS-B |
| `R/io-yaml.R` | YAML lesen/schreiben inkl. Zahlenhandler | – | WS-A |
| `R/io-excel-read.R`, `R/io-excel-write.R`, `R/io-excel-template.R` | Excel ↔ kanonische Liste, Vorlage aus Registry | `vofi_excel_template` | WS-A2 |
| `R/scenario-read.R` | Dispatch nach Format, Konstruktor, `print` | `vofi_read_scenario`, `vofi_write_scenario`, `vofi_scenario`, `vofi_example` | WS-A |
| `R/scenario-layers.R` | Schichtenmodell, Herkunft | `vofi_resolve` | WS-A |
| `R/scenario-library.R` | Bibliothekspfade, `from:`-Auflösung, Gültigkeitsprüfung | `vofi_library`, `vofi_library_paths` | WS-A |
| `R/scenario-variants.R` | Varianten, `extends`, `set`/`remove` | `vofi_variants` | WS-A |
| `R/validate-structure.R`, `R/validate-types.R`, `R/validate-refs.R`, `R/validate-plausibility.R`, `R/validate-report.R` | vier Prüfebenen, Bericht | `vofi_validate` | WS-B |
| `R/expand-measures.R`, `R/expand-unit-groups.R`, `R/expand-funding.R`, `R/expand-energy.R`, `R/expand-residual.R` | Domäne → Komponenten | – | WS-E2 |
| `R/rules-mietrecht.R`, `R/rules-co2kostaufg.R`, `R/rules-funding.R` | versionierte Rechtsregeln (Memo 02) | – | WS-E2 |
| `R/sampling.R` | Sampler-Plan, Block-Seeds, LHS, Iman-Conover, Copula, Ziehungsobjekt | – | WS-C |
| `R/dist-*.R` (je Verteilung) | `typedef_dist_*` | – | WS-C |
| `R/process-*.R` (je Prozess) | `typedef_process_*` (Prozesse nach Memo 04 §2.2) | – | WS-C |
| `R/engine-build.R` | Build: Graph, Topo-Sortierung, Sampler-Plan, Ketten, `auto` | `vofi_build` | WS-D |
| `R/engine-context.R` | `ctx` | – | WS-D |
| `R/engine-flows.R` | exogene Zeilen | – | WS-D |
| `R/engine-balance.R`, `R/account-actions.R` | Periodenschleife, Konten, Aktionen Ü1–D4 | – | WS-D |
| `R/engine-run.R`, `R/engine-checks.R`, `R/engine-store.R` | Lauf, Chunks, Invarianten, Speicherstrategie | `vofi_run`, `vofi_sim` | WS-D |
| `R/opportunity.R` | Unterlassungsalternative | `vofi_opportunity` | WS-D |
| `R/kpi-core.R`, `R/kpi-returns.R`, `R/kpi-realestate.R` | KPI-Registry, EW/ΔEW/Amortisation, Renditen (Horner-Bisektion), DSCR/ICR/LTV | `vofi_kpis`, `vofi_register_kpi` | WS-D2 |
| `R/tax-hook.R` | Schnittstelle: Generics, Steuerschlüssel-Aggregation (`tax_inputs`), Registrierung, Sperren je Perspektive | `tax_init`, `tax_step`, `tax_finalize`, `vofi_register_tax_module`, `vofi_tax_module_simple` | WS-D |
| `R/tax-none.R` | Null-Modul (läuft in jedem Lauf) | – | WS-D |
| `R/tax-flat.R`, `R/tax-selfuse.R` | Referenzmodul „Steuer-Light“ und Selbstnutzer-Bausteine nach Memo 06 §6 | – | WS-X (Steuer, Phase 2) |
| `R/type-flow-<name>.R` (je Typ) | Zahlungskomponenten | – | WS-E (mehrere Agenten) |
| `R/type-inst-<name>.R` (je Typ) | Kreditinstrumente | – | WS-F |
| `R/mc.R` | MC-Steuerung, Parallelisierung, Statistik | `vofi_mc` | WS-G |
| `R/compare.R` | Vergleich, Vergleichbarkeitsprüfung, Differenz-VoFi | `vofi_compare` | WS-G |
| `R/sensitivity.R`, `R/solve.R` | Tornado/Spider/Regression; Break-even, Entnahme-Äquivalent, kritische Werte | `vofi_sensitivity`, `vofi_solve` | WS-G |
| `R/methods-result.R`, `R/methods-mc.R`, `R/methods-compare.R`, `R/methods-misc.R` | S3-Methoden | S3 | WS-H |
| `R/report-table.R` | Grob-Tabelle, transponiert, Nutzerkostensicht | `vofi_table`, `vofi_ledger`, `vofi_tenant_view` | WS-H |
| `R/report-plot.R` | Grafiken | `vofi_plot`, `plot.*` | WS-H |
| `R/report-excel.R` | Excel-Export | `vofi_export_excel` | WS-H |
| `R/report-html.R` | Bericht | `vofi_report` | WS-H |
| `R/app.R` + `inst/shiny/vofi/` | App | `vofi_app` | WS-J (v1.1) |

### 11.2 Exportierte Funktionen (Signaturen)

```r
# Einlesen, Szenario, Validieren
vofi_read_scenario(path, format = c("auto", "yaml", "excel"), stochastic = NULL,
                   library_paths = vofi_library_paths())       # stochastic: optionale Overlay-Datei
vofi_write_scenario(scenario, path, format = c("auto", "yaml", "excel"), resolved = FALSE, overwrite = FALSE)
vofi_scenario(x, source = NULL)
vofi_example(name = NULL)
vofi_excel_template(path, example = NULL, overwrite = FALSE)
vofi_library(target = NULL, library_paths = vofi_library_paths())
vofi_library_paths(add = NULL)
vofi_variants(scenario)
vofi_resolve(scenario, variant = "base", overrides = NULL)
vofi_validate(x, variant = NULL, min_severity = c("info", "warning", "error"))
vofi_json_schema(path = NULL)

# Rechnen
vofi_time_grid(valuation_date, horizon_years, construction_months = 0L,
               construction_step = c("month", "quarter"), operation_step = "year",
               horizon_from = c("completion", "valuation"))
vofi_build(x, variant = "base", overrides = NULL)
vofi_run(model, n_sim = 1L, seed = NULL, store = c("auto", "full", "bands", "kpi"),
         chunk_size = getOption("vofi.chunk_size", 10000L))
vofi_mc(model, n_sim = 10000L, seed = NULL, sampling = c("lhs", "pseudo"), replicates = NULL,
        store = c("bands", "kpi", "full"), bands = c("net_position", "dep_balance", "od_balance"),
        keep_runs = c("p05", "p50", "p95"), parallel = FALSE,
        chunk_size = getOption("vofi.chunk_size", 10000L))
vofi_sim(x, i)                            # nicht gesetzte vofi_mc()-Argumente: aus stochastic$settings
vofi_opportunity(model)

# Analysieren
vofi_compare(..., variants = NULL, baseline = NULL, scenario_sets = NULL, n_sim = 1L, seed = NULL,
             allow_unequal = FALSE)          # baseline = NULL: project$reference_variant
vofi_sensitivity(x, params = NULL, method = c("tornado", "spider", "regression"), delta = 0.1,
                 steps = 5L, kpi = "delta_terminal_value")
vofi_solve(model, what = c("breakeven", "withdrawal_equivalent", "critical_value"), param = NULL,
           kpi = "delta_terminal_value", target = 0, interval = NULL)
vofi_kpis(x, which = NULL)

# Berichten
vofi_table(x, sim = 1L, layout = c("grob", "transposed"), detail = c("standard", "full"), periods = NULL)
vofi_ledger(x, format = c("long", "wide"), sim = NULL)
vofi_plot(x, type = NULL, ...)            # plot.<klasse>() rufen vofi_plot() auf
vofi_export_excel(x, path, overwrite = FALSE, sheets = NULL)
vofi_report(x, path, format = c("html", "docx"), mode = c("auto", "expert", "household"), template = NULL,
            title = NULL, open = interactive())
vofi_tenant_view(x, variant = NULL)          # Nutzerkostensicht (Warmmiete), Memo 07 A-20
vofi_app(scenario = NULL, launch.browser = interactive(), ...)

# Erweitern
vofi_type(name, kind, params = list(), ..., example = NULL, label = NULL, version = 1L)
vofi_register_type(def, overwrite = FALSE)
vofi_types(kind = NULL)
vofi_type_info(name)
vofi_check_type(name)
vofi_param(kind, ..., default = NULL, required = FALSE, min = NULL, max = NULL, unit = NULL,
           stochastic = FALSE, values = NULL, allow_auto = FALSE, shapes = NULL)
vofi_row(key, values, section, category, tax_category, cash = TRUE, asset_id = NULL, measure_id = NULL,
         vat_rate = 0, vat_recoverable = FALSE, label = NULL, ...)
vofi_flows(..., assets = list(), measures = list(), memo = list(), meta = list())
vofi_asset(asset_id, asset_type, in_service_period, land_share = 0, afa_method = NULL,
           useful_life_override = NULL, construction_start_date = NULL, building_application_date = NULL,
           original_completion_year = NULL, acquisition_date = NULL)
vofi_measure(measure_id, measure_type, classification = c("auto", "erhaltung", "herstellung"),
             classification_source = "default", completion_date = NULL, funding_choice = NULL, ...)
vofi_register_tax_module(name, constructor, label = NULL, perspectives = NULL, overwrite = FALSE)
vofi_tax_module_simple(name, fun, label = NULL)
tax_init(module, params, assets, measures, n_sim)               # S3-Generics (Memo 06 §7.12),
tax_step(module, t, inputs, interest, state, params)            # exportiert, damit Fremdpakete
tax_finalize(module, T, state, terminal_inputs, params)         # Methoden liefern können
vofi_register_kpi(name, compute, label = NULL, perspectives = NULL, higher_is_better = TRUE)
```

**Optionen:** `vofi.library_paths`, `vofi.chunk_size` (Vielfaches von 1.000), `vofi.max_memory_gb`, `vofi.language`
(später), `vofi.verbose`. **Bedingungen:** `vofi_error` (Basis), `vofi_error_input`, `vofi_error_validation`,
`vofi_error_registry`, `vofi_error_engine`, `vofi_warning_plausibility`, `vofi_warning_library_outdated`.

---

## 12. Parallele Implementierung durch mehrere Agenten

### 12.1 Grundsätze

1. **Verträge vor Code.** Phase 0 legt fest und friert ein: kanonisches Szenario-Schema v1, `ctx`-API,
   `vofi_flows`/`vofi_row`/`vofi_asset`, Instrument-, Aktions-, Steuer- und KPI-Schnittstellen, Ledger- und
   Ergebnisfelder, Vokabulare, Glossar, Label-Schlüsselschema. Die Dokumentation steht in
   `docs/entwicklung/vertraege.md`, die Konstruktoren und Validatoren in `R/contracts.R`. Änderungen gehen nur über den
   Integrator, mit Erhöhung von `contract_version` und Hinweis an alle Arbeitspakete.
2. **Disjunkte Dateien.** Jedes Arbeitspaket besitzt eigene Dateien (Tabelle 11.1). Gemeinsame Dateien gehören nur
   dem Integrator.
3. **Keine zentralen Listen.** Typen werden über `typedef_*` gefunden, Labels liegen je Modul bzw. Typ in eigenen
   Dateien, Tests je Datei, Snapshots je Testdatei (`_snaps/<testdatei>/`).
4. **Stubs zuerst.** Phase 0 legt alle exportierten Funktionen mit vollständiger deutscher roxygen-Doku und
   `vofi_abort("not_implemented")` in der Datei ihres späteren Eigentümers an. Damit steht `NAMESPACE` früh fest, und
   spätere Konflikte in generierten Dateien sind selten.
5. **Mocks statt Warten.** `make_ctx(n, T, params, grid)` erlaubt Typentwicklung ohne Engine.
   `example_result()`/`example_mc_result()` (Fixture nach dem Ergebnisvertrag) erlaubt Reporting ohne Engine.
   `fake_draws()` erlaubt Engine-Tests ohne Sampler.
6. **Walking Skeleton früh.** Am Ende von Phase 0 läuft YAML → `vofi_build` → `vofi_run` → `print` für ein
   Minimalszenario mit drei Typen (`equity_flows`, `custom_series`, `bullet_loan`) und den Aktionen `dep_invest`,
   `dep_withdraw`, `od_draw`, `od_repay`. Integrationsprobleme zeigen sich so in Woche 1, nicht am Ende.
7. **Definition of Done je Datei:** deutsche roxygen-Doku, Tests ≥ 90 % (Kern) bzw. ≥ 80 %, Vertragstests grün,
   `lintr` sauber, kein Nicht-ASCII in `R/`, `devtools::check()` lokal ohne WARNING/NOTE, Labels vollständig.

### 12.2 Gemeinsame Dateien (nur Integrator)

`DESCRIPTION`, `NAMESPACE` und `man/` (generiert, Agenten committen sie nicht; der Integrator führt nach dem Merge
`roxygen2::roxygenise()` aus, die CI prüft die Aktualität), `NEWS.md`, `R/vofi-package.R`, `R/zzz.R`,
`R/contracts.R`, `R/registry.R`, `R/vocab.R`, `R/labels.R`, `R/conditions.R`, `R/utils-*.R`, `inst/vocab/*`,
`inst/labels/de/core.yaml`, `tests/testthat/helper-contracts.R`, `helper-fixtures.R`, `.Rbuildignore`, `.lintr`,
CI-Konfiguration. Agenten, die einen neuen Hilfsbedarf haben, legen `helper-<ws>.R` an oder stellen beim Integrator
einen Änderungsantrag.

### 12.3 Phasen und Reihenfolge

```text
Phase 0  (seriell, 1 Agent „Integrator/Architekt“)
  Paketgerüst, DESCRIPTION mit allen absehbaren Imports/Suggests, Verträge, Registry, Vokabulare, Label-Lader,
  Utils (Merge, Pfade, Format, Hash, Seed), Stubs aller Exporte, Testhelfer (make_ctx, example_result,
  fake_draws, expect_vofi_flows_contract), CI (R CMD check, Tests, lintr, covr) mit LANG=C.UTF-8,
  Walking Skeleton.
        │
        ▼
Phase 1  (parallel, 6–8 Agenten, nur gegen Verträge und Mocks)
  WS-A  Eingabe: io-yaml, scenario-read/layers/library/variants, Beispielszenarien (YAML)
  WS-A2 Excel: io-excel-read/write/template, data-raw/build_template.R
  WS-B  Schema/Validierung/Ausdrücke: schema, validate-*, expr
  WS-C  Sampling: sampling, dist-*, process-*
  WS-D  Engine: time-grid, values, engine-*, account-actions, opportunity, tax-hook, tax-none
  WS-E  Flow-Typen: type-flow-* (auf 2–3 Agenten nach Typen aufteilbar)
  WS-F  Instrumente: type-inst-* (Memo-01-Kreditbausteine, Test (f))
  WS-H  Reporting: methods-*, report-table/plot/excel (gegen example_result)
  WS-T  Orakel & Referenz-Engine: fixtures/oracles aus Memo 01 §10 (CSV), helper-reference-engine.R,
        Szenariengenerator für Differenztests  (bewusst ein anderer Agent als WS-D)
        │
        ▼
Phase 2  (Integration + parallel 4–6 Agenten)
  Integrator: Merge-Reihenfolge D → C → F → E → A → B → A2 → H; End-to-End-Tests, Orakel grün
  WS-D2 KPIs (kpi-*), WS-G MC/Vergleich/Sensitivität/Solve, WS-E2 Expander + Rechtsregeln (Memo 02),
  WS-H2 HTML/DOCX-Bericht (Fach- und Haushaltsmodus), Bibliothekseinträge (Fachagent, nur inst/extdata/library)
  WS-X  Steuermodule tax_flat, tax_selfuse (Memo 06 §6) gegen die in Phase 1 fertige Schnittstelle
  WS-S  Referenzszenarien S1–S5 (Memo 07) als YAML + Prüfwerte (nur inst/extdata/examples, tests/fixtures)
        │
        ▼
Phase 3  (Härtung)
  Vignetten (deutsch), Performance-Benchmarks und -Tests, Abdeckung, R CMD check --as-cran,
  Excel-Vorlage final, v1.1: WS-J Shiny-App
```

### 12.4 Schnittstellen zwischen den Arbeitspaketen

| Liefert | an | Vertrag | Mock bis zur Lieferung |
|---|---|---|---|
| WS-A (kanonische Liste) | WS-B, WS-D | Schema v1 (4.2), Herkunftsattribut | handgeschriebene Listen in `fixtures/scenarios/` |
| WS-B (Parameter-DSL) | WS-E, WS-F, WS-A2 | `vofi_param()`-Felder | Phase-0-Minimalversion von `vofi_param()` |
| WS-C (Ziehungen) | WS-D | `draws`-Objekt (Schlüssel → N-Vektor bzw. N × T) | `fake_draws()` |
| WS-D (`ctx`, Ledger, Ergebnis) | WS-E, WS-F, WS-H, WS-G | 5.3, 6.4, 6.10 | `make_ctx()`, `example_result()` |
| WS-E/F (Typen) | WS-D, WS-A2 | 5.2, 5.4, 5.5 | Phase-0-Skelett-Typen |
| WS-T (Orakel) | alle | CSV-Format `row_key, t, value` | – |

### 12.5 Konfliktvermeidung in Git

- Ein Branch je Arbeitspaket, kleine PRs, CI auf jedem PR.
- Nur Dateien aus der eigenen Zuständigkeitsliste (`docs/entwicklung/zustaendigkeiten.md`) ändern.
- Keine Änderungen an generierten Dateien (`NAMESPACE`, `man/`, Vorlage XLSX) außerhalb des Integrators bzw. des
  Generatorskripts.
- Rebase vor dem Merge. Der Integrator merged in fester Reihenfolge und führt danach die vollständige Testsuite aus.
- Fachliche Unklarheiten (z. B. Tilgungszuschuss-Wirkung) werden nicht im Code entschieden. Sie gehen als Frage an
  den Integrator und werden in den Verträgen oder im Glossar festgehalten.

---

## 13. Offene Fragen an den Auftraggeber

1. **Paketname und Lizenz:** `vofi` (CRAN-frei) einverstanden? Welche Lizenz (MIT, GPL-3, proprietär/intern)? Ist eine
   CRAN-Veröffentlichung geplant oder nur intern (GitHub)?
2. **Enum-Werte:** Memo 02 verwendet deutsche Codes (`wu_kommunal`, `selbstnutzer`, `sanierung_eh`). Vorschlag:
   übernehmen (ASCII-snake_case, Fachbegriffe deutsch), Schlüssel bleiben englisch. Einverstanden?
3. **Vergleichsmodus Sanierung:** Memo 01 (E6) empfiehlt Total-VoFis mit ΔEW, Memo 02 nennt `differential` als Standard
   für Sanierung. Vorschlag: Total-VoFi als Standard, `differential` als gekennzeichneter Vereinfachungsmodus.
   Einverstanden?
4. **Raster in v1:** Memo 01 (E7) empfiehlt das nicht äquidistante Raster (Bauphase monatlich) schon für v1, Memo 07
   (A-02) die jährliche VoFi mit monatsgenauer Kreditrechnung und die unterjährige Bauphase erst in v2. Die Architektur
   unterstützt beides (Raster als Vektor Δ_t). Der Mehraufwand liegt vor allem in Krediten und Tests. Entscheidung?
5. **Excel-Bibliothek:** `openxlsx` (installiert, Wartungsmodus) oder Umstieg auf `openxlsx2` (aktiv entwickelt, nicht
   installiert)?
6. **Shiny:** v1.1 als Viewer ausreichend? Wo würde die App laufen (lokal, Shiny Server, Posit Connect)? Sind die
   Szenariodaten vertraulich?
7. **Testorakel aus der Praxis:** Gibt es vorhandene Excel-VoFis des Auftraggebers oder eines Wohnungsunternehmens, die
   als zusätzliche Orakel dienen können?
8. **Berichtslayout:** Gibt es Corporate-Design-Vorgaben oder Pflichtkennzahlen (z. B. DSCR-Covenants, Konzernvorgaben)?
9. **Bibliothekspflege:** Wer aktualisiert Förderkonditionen und Preispfade, in welchem Rhythmus? Soll das Tool beim
   Start auf veraltete Einträge hinweisen?
10. **Ausdrücke:** Soll der sichere Ausdrucksauswerter auch für frei formulierte abgeleitete Parameter freigegeben werden
    oder nur für Förderbedingungen? (Memo 07 nutzt ihn bereits für Kostenformeln, z. B. Fläche × €/m².)
11. **Abstimmung der Codes zwischen den Memos** (vor Phase 0 festzulegen, dann im Glossar und den Vokabularen fixiert):
    - Perspektiven: Memo 02 (`wu_kommunal`, `wu_genossenschaft`, `wu_privat`, `kleinvermieter`, `selbstnutzer`) und
      Memo 06 (`privat_vermieter`, `wu_kapges`, `wu_eg_befreit`, `wu_eg_stpfl`, `wu_kommunal`, `wu_gemeinnuetzig`,
      `selbstnutzer`). Vorschlag: `perspective` nach Memo 02 plus getrenntes Feld `tax_regime` nach Memo 06.
    - KPI-Schlüssel: Memo 04 verwendet `endwert`/`endwert_diff`, dieses Memo `terminal_value`/`delta_terminal_value`
      (englische Bezeichner nach Projektvorgabe). Vorschlag: englische Schlüssel, deutsche Labels über den Katalog.
    - Tilgungszuschuss-Wirkung: Memo 01 (`shorten_term`/`reduce_installment`), Memo 02 (`reduce_principal`/
      `reduce_annuity`/`shorten_term`), Memo 07 (`term_reduction`/`payment_reduction`). Vorschlag: Memo-01-Codes.
    - Projektarten: Memo 02 (`sanierung_eh`, …) und Memo 07 (`sanierung_stufenweise`). Vorschlag: Vokabular `enums.yaml`
      als einzige Quelle, Memo-07-Wert ergänzen.

---

## 14. Risiken

| Risiko | Wirkung | Gegenmaßnahme |
|---|---|---|
| Umfang der Domäne (viele Typen, Rechtsregeln, Förderlogik) sprengt v1 | Verzögerung | fester v1-Typkatalog (5.12), `custom_series` als Ausweg, Expander später ausbaubar |
| Fehler in Vorzeichen, Ausgleich oder Zinskonventionen | falsche Entscheidungen | Orakel (a)–(f), Invarianten in jedem Lauf, Referenz-Engine eines anderen Agenten |
| Vektorisierungsfehler (`max` statt `pmax`, fehlendes `drop = FALSE`, Zeitvektor stillschweigend entlang der Zeilen recycelt) | Läufe beeinflussen sich gegenseitig | Vertrags- und Batch-Invarianztests für jeden Typ, Tests mit N = 1 und 2 |
| Uneinheitliche Begriffe und Schlüssel paralleler Agenten | Integrationsaufwand | Glossar (3.6), Vokabulare, Verträge, Vertragstests |
| Steuermodul braucht später Informationen, die heute fehlen | Refactoring | Pflicht-Tags und Assets ab v1 (5.11), Test „Steuerbereitschaft“, `step`-Schnittstelle mit Zustand |
| Veraltete Bibliotheksdaten (Förderung, CO2-Preis, Recht) | falsche Annahmen | Gültigkeits- und Abrufdaten, Warnungen, Herkunft im Bericht |
| Speicher bei großen N × T × Zeilen | Abbruch | `store`-Strategie, Speicherschätzung, Chunks |
| Umlaute und Locale in CI/`R CMD check` | WARNINGs, kaputte Snapshots | Label-Katalog, `LANG=C.UTF-8`, `skip_if_not(UTF-8)` |
| openxlsx in Wartungsmodus | spätere Inkompatibilität | Kapselung in zwei Dateien, Wechsel zu openxlsx2 vorbereitet |
| Excel-Vorlage und Registry laufen auseinander | Lesefehler | Vorlage generiert, Strukturtest |
| Scheingenauigkeit bei MC (Nutzer lesen Mittelwerte als sicher) | Fehlinterpretation | MC-Standardfehler, Konvergenzgrafik, Pflichtsensitivitäten, Hinweis deterministisch ≠ Erwartungswert |
| Neue Paketversionen (ggplot2 4.x, shiny 1.14) gegenüber der Installationsbasis | Inkompatibilität | CI-Matrix mit apt-Ständen und aktuellem CRAN, stabile APIs |
| Ausgleichsheuristiken (Ü3) bilden suboptimale Finanzierungspolitik ab | verzerrte EW | Ü3 standardmäßig aus, Warnhinweis (Memo 01 §3.2) |

---

## Anhang A: Performance-Prototyp P3 (Zustandsautomaten + Aktionsketten)

Dieser Prototyp ist **fachlich vereinfacht** (z. B. Annuitätsbestimmung, keine Bereitstellungsprovision) und nur für
Laufzeitmessungen gedacht. Er ist kein Orakel. Er zeigt, dass die empfohlene Schleifenstruktur (Abschnitt 6.5)
performant ist: N = 10.000, 83 Perioden ≈ 0,30 s; N = 1 ≈ 10 ms; max. |Finanzierungssaldo| ≈ 1e-10.

```r
make_grid <- function(construction_months = 12, years = 70) {
  delta <- c(0, rep(1 / 12, construction_months), rep(1, years))   # Periode 0 hat Länge 0
  list(T = length(delta) - 1, delta = delta, tau = cumsum(delta))
}

# Kredit als Zustandsautomat: Teilvalutierung, tilgungsfreie Zeit, Zinsbindung mit
# stochastischem Anschlusszins (keep_tilg_rate), Tilgungszuschuss
loan_annuity <- function(id, commit, draws_at, rate_pa, fix_until_tau, followup,
                         tilg_rate, grace_periods, tz_share, tz_at) {
  init <- function(n) list(B = rep(0, n), A = rep(0, n), i_pa = rep(rate_pa, n))
  step <- function(st, t, g) {
    n <- length(st$B); d <- g$delta[t + 1]
    if (g$tau[t + 1] > fix_until_tau && g$tau[t] <= fix_until_tau) {
      st$i_pa <- followup[, t + 1]
      st$A <- st$B * (st$i_pa + tilg_rate)
    }
    Z <- st$B * st$i_pa * d
    D <- if (t %in% draws_at) rep(commit / length(draws_at), n) else rep(0, n)
    last_draw <- max(draws_at)
    Tl <- if (t > last_draw + grace_periods) pmin(pmax(st$A * d - Z, 0), st$B) else rep(0, n)
    if (t == last_draw + grace_periods) st$A <- (st$B + D) * (rate_pa + tilg_rate)
    st$B <- st$B + D - Tl
    TZ <- if (t == tz_at) pmin(commit * tz_share, st$B) else rep(0, n)
    st$B <- st$B - TZ
    list(state = st, flows = list(draw = D, interest = -Z, repay = -Tl), memo = list(grant = TZ))
  }
  list(id = id, init = init, step = step)
}

# Ausgleichsaktionen: nehmen einen Betrag, geben den verbrauchten Teil zurück
act_od_repay     <- function(acc, amt) { x <- pmin(amt, acc$KK); acc$KK <- acc$KK - x
                                         list(acc = acc, used = x, flow = -x, row = "od_repay") }
act_dep_invest   <- function(acc, amt) { acc$G <- acc$G + amt
                                         list(acc = acc, used = amt, flow = -amt, row = "dep_invest") }
act_dep_withdraw <- function(acc, amt) { x <- pmin(amt, pmax(acc$G - acc$Lmin, 0)); acc$G <- acc$G - x
                                         list(acc = acc, used = x, flow = x, row = "dep_withdraw") }
act_od_draw      <- function(acc, amt) { x <- pmin(amt, pmax(acc$KL - acc$KK, 0)); acc$KK <- acc$KK + x
                                         list(acc = acc, used = x, flow = x, row = "od_draw") }
act_equity_call  <- function(acc, amt) list(acc = acc, used = amt, flow = amt, row = "equity_call")

engine <- function(n, g, exo, loans, h_pa = 0.02, s_pa = 0.09, KL = 5e4, tax_step = NULL) {
  T1 <- g$T + 1
  rows <- c("od_repay", "dep_invest", "dep_withdraw", "od_draw", "equity_call",
            "od_interest", "dep_interest", "tax")
  rec <- lapply(setNames(rows, rows), function(r) matrix(0, n, T1))
  for (l in loans) for (r in c("draw", "interest", "repay"))
    rec[[paste0("loan_", l$id, "_", r)]] <- matrix(0, n, T1)
  stockG <- stockKK <- stockB <- matrix(0, n, T1)
  acc <- list(G = rep(0, n), KK = rep(0, n), Lmin = 0, KL = KL)
  ls <- lapply(loans, function(l) l$init(n))
  surplus_chain <- list(act_od_repay, act_dep_invest)                  # Ü1, Ü4
  deficit_chain <- list(act_dep_withdraw, act_od_draw, act_equity_call) # D1, D2, D4
  for (t in 0:g$T) {
    j <- t + 1; d <- g$delta[j]
    F <- exo[, j]
    for (k in seq_along(loans)) {                                       # Kreditautomaten
      r <- loans[[k]]$step(ls[[k]], t, g); ls[[k]] <- r$state
      for (nm in names(r$flows)) {
        rec[[paste0("loan_", loans[[k]]$id, "_", nm)]][, j] <- r$flows[[nm]]
        F <- F + r$flows[[nm]]
      }
    }
    HZ <- acc$G * ((1 + h_pa)^d - 1); KZ <- acc$KK * ((1 + s_pa)^d - 1) # Zinsen auf Vorperiodenbestände
    S <- F + HZ - KZ
    St <- if (is.null(tax_step)) 0 else tax_step(t, F, HZ, KZ)          # Steuer-Slot
    S <- S + St
    sur <- pmax(S, 0); def <- pmax(-S, 0)                               # Ausgleich, vektorisiert
    for (a in surplus_chain) { r <- a(acc, sur); acc <- r$acc; sur <- sur - r$used
                               rec[[r$row]][, j] <- rec[[r$row]][, j] + r$flow }
    for (a in deficit_chain) { r <- a(acc, def); acc <- r$acc; def <- def - r$used
                               rec[[r$row]][, j] <- rec[[r$row]][, j] + r$flow }
    rec$od_interest[, j] <- -KZ; rec$dep_interest[, j] <- HZ; rec$tax[, j] <- St
    stockG[, j] <- acc$G; stockKK[, j] <- acc$KK
    stockB[, j] <- Reduce(`+`, lapply(ls, `[[`, "B"))
  }
  saldo <- exo + Reduce(`+`, rec)                                       # Finanzierungssaldo (I1)
  list(EW = acc$G - acc$KK - stockB[, T1], max_saldo = max(abs(saldo)), rec = rec,
       BS = stockG - stockKK - stockB)
}
```

Testaufruf (Auszug): EK 400.000 in t = 0; Baukosten 2,0 Mio. über 12 Monate mit lognormalem Kostenaufschlag; NOI
110.000 p. a. mit AR-freiem Wachstum N(2 %, 1 %); KfW-artiger Kredit 1,2 Mio. (6 Monatstranchen, 3,53 %, 3 Perioden
tilgungsfrei, 5 % Tilgungszuschuss) und Bankkredit 0,6 Mio. (3,9 %), Anschlusszins N(4,5 %, 1 %) nach 11 Jahren.

## Anhang B: Benchmark-Protokoll (Kurzfassung)

- **P1** (handgeschriebener Kern, 20 Zeilen): Treiber über korrelierte Normalschocks (Cholesky), AR(1)-Mietwachstum,
  GBM-Energiepreis, Vasicek-Anschlusszins, Dreieck-Baukostenfaktor, Beta-Leerstand. Komponenten: Investition, Miete,
  Bewirtschaftung, Instandhaltung, Energie, Restwert. Zwei Annuitätendarlehen (eins mit Tilgungszuschuss und
  tilgungsfreien Jahren), Ausgleich mit KK-Limit und Nachschuss. Max. |Finanzierungssaldo| über alle Läufe und Perioden:
  9,3e-10 (T = 40) bzw. 3,7e-9 (T = 80).
- **P2** (generischer Registry-Kern): Registry als Umgebung, `ctx$resolve()` für Konstante, Verteilung und Treiber,
  Block-Seed je Parameterpfad, 22 Komponenten (davon 20 `share_of`), drei Finanzierungsbausteine inkl.
  `amount_eur: auto`, Steuer-Hook (`prepare`/`step`) mit pauschaler AfA aus Asset-Basis. CRN-Test: identische
  Baukostenziehung in zwei Varianten mit unterschiedlicher Komponentenzahl.
- **P3**: siehe Anhang A.
- **Architekturvergleich** der Ausgleichsschleife: vektorisiert, skalar, R6 je Lauf, dplyr/purrr je Lauf (Tabelle 2.5).
- **Weitere Messungen:** Parallelisierung mit `future::multisession` (4 Worker), Byte-Compiler an/aus, Quantilbänder,
  vektorisierte Renditebestimmung (naiv vs. Horner), Skalierung in N.
- **Umlaut-Test:** Minimalpaket mit `R CMD check` (WARNING bei Umlauten im R-Code, OK mit Label-Datei).
- **YAML-Test:** Verhalten von `yaml.load()` bei `3,5`, `150.000`, `1.234.567`, `150_000`, `1e-2`, `yes`/`no`, `~` sowie eigene
  Handler.
- **Excel-Test:** openxlsx-Vorlage mit Auswahlliste auf verstecktem Blatt, Zurücklesen im Langformat und Umwandlung
  in die verschachtelte kanonische Liste.
