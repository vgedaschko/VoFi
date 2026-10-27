# vofi

R-Paket für den **Vollständigen Finanzplan (VoFi)** nach Grob mit Monte-Carlo-Simulation. Es
bewertet Neubau und energetische Sanierung von Wohngebäuden in Deutschland aus Sicht von
Wohnungsunternehmen (kommunal, privat, Genossenschaft), privaten Vermietern und Selbstnutzern.

Typische Fragen:

- Lohnt sich die Sanierung auf EH 70 gegenüber der Ohnehin-Sanierung? Wie verändert sich die
  Warmmiete?
- Wärmepumpe jetzt oder Gaskessel behalten? Was kostet das die Familie im Monat, und wann hat
  sich die Investition bezahlt gemacht?
- Wie robust ist das Ergebnis, wenn Zinsen, Energie- und CO₂-Preise anders kommen?

Jede Rechnung ist ein vollständiger Finanzplan: Alle Zahlungen laufen über Konten mit Haben- und
Sollzins. Die Hauptkennzahl ist die **Endwertdifferenz** gegenüber einer Referenzvariante, mit
und ohne Restwert. Dazu kommen Rendite, Amortisation, DSCR/LTV, Liquidität, Warmmiete,
monatliche Belastung und CO₂.

## Status

Version 0.1.0, Funktionsumfang v1. Diese Teile sind umgesetzt und getestet:

- Einlesen von Szenarien aus YAML und Excel, geschichtete Parameterbibliothek mit Herkunft je
  Wert, Validierung mit deutschen Meldungen
- deterministischer Lauf, Variantenvergleich mit gemeinsamen Zufallszahlen, Monte-Carlo-Simulation
- Sensitivität (Tornado, Spider, global), Zielwertsuche und kritische Werte (`vofi_solve()`)
- Berichte als HTML im Fach- und im Haushaltsmodus, druckfähige Kurzvorlage für Gremien,
  Excel-Export, Grafiken

Offene fachliche Befunde aus der Verifikation stehen in `docs/pruefung/offene_befunde.md`.
DOCX-Berichte und ein Shiny-Viewer (`vofi_app()`) sind vorbereitet, aber noch nicht freigegeben.

## Installation

Benötigt wird R ab 4.3 (entwickelt und geprüft mit R 4.3.3). Das Repository ist privat, deshalb
braucht `remotes` ein GitHub-Token mit Lesezugriff:

```r
install.packages("remotes")
Sys.setenv(GITHUB_PAT = "ghp_...")   # oder dauerhaft in ~/.Renviron
remotes::install_github("vgedaschko/VoFi", ref = "ccr-e39370a2-0udv4w")
```

Pflicht sind nur `yaml` und `openxlsx`. Für Grafiken im Bericht empfiehlt sich `ggplot2`, für
parallele Simulationen `future.apply`.

Aus einem lokalen Checkout installieren Sie das Paket mit `devtools::install()` bzw.
`R CMD INSTALL .`.

## Schnellstart mit den Beispielen S1 bis S5

Das Paket enthält fünf Referenzszenarien als YAML und Excel:

| Name | Fall |
|---|---|
| `s1_wu_mfh_1963_eh70` | Wohnungsunternehmen: MFH 1963, Sanierung auf EH 70 gegenüber Ohnehin-Sanierung, Warmmiete |
| `s2_wu_neubau_mfh_36we` | Wohnungsunternehmen: Neubau MFH 36 WE mit KfW 298 und Anschlussfinanzierung |
| `s3_eg_waermepumpe_pv` | Genossenschaft: Gas auf Wärmepumpe mit PV, Umlage nach § 559e |
| `s4_efh_1975_isfp` | Selbstnutzer: EFH 1975, stufenweise Sanierung nach iSFP gegenüber Gaskessel behalten |
| `s5_neubau_efh_eh40` | Familie: Neubau EFH EH 40 mit KfW 300 gegenüber GModG-Standard |

```r
library(vofi)
vofi_example()                      # alle Beispielnamen
sc <- vofi_read_scenario(vofi_example("s4_efh_1975_isfp"))
vofi_variants(sc)                   # Varianten mit Bezeichnung
```

### Eine Variante rechnen

```r
res <- vofi_run(vofi_build(sc, variant = "v2_nur_wp"))
res                                  # Kopfwerte
k <- vofi_kpis(res)                  # alle Kennzahlen (mit NA-Begründung)
k[k$kpi %in% c("monthly_burden_y1", "own_contribution"), c("kpi", "value")]
vofi_table(res)                      # VoFi-Tabelle je Jahr
head(vofi_household_view(res))       # Haushaltssicht in EUR pro Monat
```

`vofi_build()` löst Bibliothek, Profile und Variante auf und baut das Modell, `vofi_run()`
rechnet es. Mit `overrides` lassen sich einzelne Werte für einen Lauf ändern, ohne das Szenario
anzufassen.

### Varianten vergleichen, mit und ohne Simulation

```r
cmp <- vofi_compare(sc)                              # Basisfall, alle Varianten gegen die Referenz
cmp
cmp_mc <- vofi_compare(sc, n_sim = 200, seed = 1)    # Monte Carlo mit gemeinsamen Zufallszahlen
cmp_mc
```

Für belastbare Aussagen sind 1.000 Läufe die Vorschau und 10.000 der Standard. Die Referenz ist
`project.reference_variant` des Szenarios (sonst `base`).

### Berichte und Excel-Export

```r
out <- tempdir()
vofi_report(cmp_mc, file.path(out, "s4_haushalt.html"), mode = "household", open = FALSE)
vofi_report(cmp_mc, file.path(out, "s4_fach.html"), mode = "expert", open = FALSE)

s1 <- vofi_compare(vofi_read_scenario(vofi_example("s1_wu_mfh_1963_eh70")))
vofi_report(s1, file.path(out, "s1_gremium.html"), template = "gremium", open = FALSE)

vofi_export_excel(cmp, file.path(out, "s4_vergleich.xlsx"))
```

- `mode = "household"`: Klartext für Haushalte, gerundete Monatsbeträge, Förderung und Kredite,
  Risiko in einfachen Worten, Glossar
- `mode = "expert"`: Fachbericht mit allen Kennzahlen, VoFi-Tabellen, Pflichtsensitivitäten,
  Annahmenprotokoll und Methodik
- `template = "gremium"` (gleichbedeutend `"kurzvorlage"`): druckfähige Kurzvorlage für
  Aufsichtsrat, Vertreterversammlung oder Bank; als PDF über den Druckdialog des Browsers

Weitere Auswertungen: `vofi_tenant_view()` (Mietersicht, Warmmiete), `vofi_plot()`,
`vofi_sensitivity()` und `vofi_solve()`, zum Beispiel die warmmietenneutrale Umlage in S1:

```r
s1_sc <- vofi_read_scenario(vofi_example("s1_wu_mfh_1963_eh70"))
sol <- vofi_solve(s1_sc, param = "unit_groups.bestand.rent_law.voluntary_cap_per_m2",
                  kpi = "warm_rent_change_prepost_y1", target = 0,
                  variant = "v2_eh70", interval = c(0, 2))
sol$value                            # rund 1,05 EUR/m² und Monat
```

## Eingabe über Excel

Wer nicht mit YAML arbeiten möchte, füllt die Excel-Vorlage aus. Sie enthält je Themenblock ein
Blatt mit deutschen Bezeichnungen, Einheiten, Vorgaben und Auswahllisten. Gelbe Zellen sind
Eingaben.

```r
f <- file.path(tempdir(), "mein_fall.xlsx")
vofi_excel_template(f)                                   # leere Vorlage
vofi_excel_template(f, example = "s4_efh_1975_isfp", overwrite = TRUE)   # mit Beispiel
# ... Datei in Excel ausfüllen und speichern ...
sc_x <- vofi_read_scenario(f)
vofi_validate(sc_x)
```

Eine Datei aus `vofi_excel_template(f, example = ...)` entspricht `vofi_write_scenario()` und
lässt sich ohne Verlust wieder einlesen. Jedes Beispiel liegt auch als fertige `.xlsx` neben der
YAML-Datei:

```r
xl <- sub("\\.yaml$", ".xlsx", vofi_example("s4_efh_1975_isfp"))
sc_xl <- vofi_read_scenario(xl)
```

## Ein eigenes Szenario anlegen

Am schnellsten geht es, wenn Sie das passende Beispiel aus `inst/extdata/examples/` kopieren
(S1/S3 für Wohnungsunternehmen im Bestand, S2 für Neubau, S4 für Selbstnutzer im Bestand, S5 für
den Neubau eines Haushalts) und anpassen. Alle Felder mit Einheit, Default und Prüfregel stehen im
Feldkatalog:

- `docs/spec/01a_feldkatalog_projekt_investition_finanzierung.md`: Projekt, Gebäude, Maßnahmen,
  Finanzierung, Konten
- `docs/spec/01b_feldkatalog_betrieb_energie_foerderung.md`: Mieten und Mietrecht,
  Bewirtschaftung, Energie und CO₂, Förderung, Haushalt
- `docs/spec/01c_feldkatalog_stochastik_bibliothek_szenarien.md`: Unsicherheiten, Prozesse,
  Korrelationen, Bibliothek, Varianten und Szenario-Sets

Ein minimales, lauffähiges Szenario mit einer Variante:

```yaml
schema_version: 1
meta: {scenario_id: mini, title: "Mini: Zahlungsreihe mit Bankkredit"}
project: {perspective: wu_privat, project_type: neubau, valuation_date: 2027-01-01,
          horizon_years: 3}
components:
  z: {type: custom_series, label: "Zahlungsfolge", values: [-100000, 30000, 40000, 50000]}
financing:
  ek:   {type: equity, amount_eur: 40000}
  bank: {type: bullet_loan, amount_eur: 60000, rate_pa: 0.05, term_years: 3,
         payments_per_year: 1}
accounts: {deposit_rate_pa: 0.02, overdraft_rate_pa: 0.08}
variants:
  teurer:
    label: "Höhere Anfangsauszahlung"
    set: {components.z.values: [-110000, 30000, 40000, 50000]}
```

```r
f <- file.path(tempdir(), "mini.yaml")
writeLines(c(
  "schema_version: 1",
  "meta: {scenario_id: mini, title: \"Mini: Zahlungsreihe mit Bankkredit\"}",
  "project: {perspective: wu_privat, project_type: neubau, valuation_date: 2027-01-01,",
  "          horizon_years: 3}",
  "components:",
  "  z: {type: custom_series, label: \"Zahlungsfolge\", values: [-100000, 30000, 40000, 50000]}",
  "financing:",
  "  ek:   {type: equity, amount_eur: 40000}",
  "  bank: {type: bullet_loan, amount_eur: 60000, rate_pa: 0.05, term_years: 3,",
  "         payments_per_year: 1}",
  "accounts: {deposit_rate_pa: 0.02, overdraft_rate_pa: 0.08}",
  "variants:",
  "  teurer:",
  "    label: \"Höhere Anfangsauszahlung\"",
  "    set: {components.z.values: [-110000, 30000, 40000, 50000]}"
), f, useBytes = TRUE)
mini <- vofi_read_scenario(f)
vofi_validate(mini)
vofi_compare(mini)
```

Hinweise für eigene Fälle:

- Gebäude, Maßnahmen, Energie und Förderung beschreiben Sie fachlich (Domänenblöcke). Die
  Expander übersetzen sie in Zahlungskomponenten. `components` brauchen Sie nur für Sonderfälle.
- Werte aus der Bibliothek holen Sie mit `{from: <eintrag>, use: <teil>}`, z. B. Förderprogramme
  (`funding/kfw_458_heizung_privat`) oder Preisszenarien (`prices/referenzszenarien_2026`).
  Bezieht sich der Markt-Block auf `shared.*`, muss der `shared`-Block derselben Quelle mit
  eingebunden sein (siehe S4).
- Varianten ändern die Basis mit `set`, `add`, `remove` und `replace`. `set` verlangt einen Pfad,
  den die Elternvariante schon kennt.
- `vofi_validate()` vor dem ersten Lauf: Die Meldungen nennen Pfad und, wo möglich, die Lösung.

## Was modelliert ist und was nicht

Abgebildet sind unter anderem:

- Investition nach DIN 276 mit Bauphase, Ohnehin-Anteil, Ersatzinvestitionen und Restwert
  (mehrere Methoden, alles auch ohne Restwert)
- Mieten mit Mietrecht: § 558 mit Kappungsgrenze und Wartefrist, Staffel- und Indexmiete,
  Bindung, Modernisierungsumlage nach §§ 559, 559c und 559e mit Kappungen, freiwilliger bzw.
  warmmietenneutraler Begrenzung, Mietpreisbremse
- Energie und CO₂ je Energieträger: CO₂-Preis nach BEHG/ETS 2, Kostenaufteilung nach
  CO2KostAufG einschließlich § 5a, PV mit Eigenverbrauch und Einspeisung, Treibhausgasbilanz
- Förderung (KfW, BAFA, § 35c EStG) mit Berechtigungs-Check, Zusage als Zufallsereignis mit
  Ausweichvariante, Förderkredite mit tilgungsfreien Jahren und Tilgungszuschuss
- Finanzierung mit Annuitäten-, Raten- und endfälligen Darlehen, Anschlusszins, Kontokorrent und
  Nachschüssen; Haushaltssicht mit Belastungsquote und Sparfähigkeit
- Unsicherheit über Zins-, Inflations- und Energiepreisprozesse, CO₂-Korridore,
  Kostenüberschreitung, Performance-Gap und Förderzusage

Nicht oder nur vereinfacht abgebildet:

- **Die Rechnung ist vor Ertragsteuern.** Das Modul `tax_flat` (`tax: {module: flat}`) ist eine
  optionale, grobe Näherung für Vermieter. Für Selbstnutzer und steuerbefreite Unternehmen ist es
  gesperrt. Optional lässt sich die Abgeltungsteuer auf Habenzinsen ansetzen.
- Kosten sind brutto (kein Vorsteuerabzug). Grunderwerbsteuer und Grundsteuer sind enthalten.
- Keine Optimierung der Finanzierung, keine Kündigungsrechte und keine
  Vorfälligkeitsentschädigung. Restschulden werden am Horizont nominal abgezogen.
- Ein Gebäude bzw. Projekt je Szenario. Portfolio, WEG, Kostenmiete nach II. BV und gemischte
  Nutzung sind nicht enthalten, ebenso keine stündliche Energiesimulation und keine Mieter-VoFi.
- Mietrecht, Förderbedingungen und CO₂-Kostenaufteilung sind vereinfacht. Die Ergebnisse
  ersetzen weder Energie-, Förder-, Rechts- oder Steuerberatung noch die Prüfung im Einzelfall.

## Parameterbibliothek

Die mitgelieferte Bibliothek liegt in `inst/extdata/library/`, eine YAML-Datei je Eintrag mit
Quelle, Stand (`as_of`), Gültigkeit (`valid_from`, `valid_to`), Qualitätsstufe und Rechtsstand.
Der Bibliotheksstand steht in `inst/extdata/library/VERSION` (derzeit `2026.10.2`, Werte mit
Stichtag 25.10.2026) und erscheint in jedem Ergebnis und Bericht.

```r
lib <- vofi_library(block = "funding", date = as.Date("2027-01-01"))
lib[, c("entry", "label", "valid_from", "valid_to", "outdated")]
```

- Eigene oder aktualisierte Einträge legen Sie in einem eigenen Verzeichnis ab und binden es mit
  `options(vofi.library_paths = "<pfad>")` bzw. `vofi_library_paths(add = ...)` ein. Bei gleicher
  id gewinnt der spätere Pfad.
- Ein Eintrag gilt als veraltet, wenn der Stichtag außerhalb seiner Gültigkeit liegt oder sein
  Stand älter als 6 Monate ist (Prozesse und Kalibrierungen: 12 Monate). Die Rechnung warnt dann.
  Werte, die bis zu einer Neufassung fortgelten, tragen `valid_to: null` und in `notes` den
  Prüfpunkt.
- Pflegetermine: Förderung KfW/BAFA zum 01.02. und 01.08. (Degression KfW 458 ab 01.02.2027),
  EEG-Einspeisevergütung halbjährlich, Energiepreise und Zins-Startwerte vierteljährlich,
  CO₂-Korridore jährlich, ImmoWertV-Bewirtschaftungskosten jährlich im Januar, II. BV alle drei
  Jahre (nächste Anpassung 01.01.2029), Baupreise halbjährlich, Steuerparameter jährlich. Der
  vollständige Kalender steht im Konzept, Abschnitt 6.3.

## Konzept und Spezifikation

- `docs/Konzept.md`: fachliches Konzept, Methodik, Grenzen, Entscheidungen
- `docs/spec/00_kernvertraege.md`: verbindliche Kernverträge (Datenmodell, Engine, Kennzahlen,
  Berichte)
- `docs/spec/01a_*.md` bis `01c_*.md`: Feldkatalog des Szenarios
- `docs/recherche/`: Fachrecherchen (Methodik, Recht und Förderung, Parameter, Monte Carlo,
  Architektur, Steuern, Anwendungsfälle)
- `docs/pruefung/offene_befunde.md`: Stand der Verifikation

## Entwicklung

```sh
Rscript -e 'devtools::test()'     # Testsuite
tools/check.sh --no-tests         # R CMD check ohne Tests
```

Bezeichner im Code sind englisch, alle Nutzertexte stehen deutsch in den Label-Katalogen
`inst/labels/de/`.
