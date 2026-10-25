# 03 – Default-Parameterbibliothek mit Quellen und Unsicherheitsbereichen (Stand 25.10.2026)

> **Zweck.** Dieses Memo liefert (1) deterministische Standardwerte für die editierbaren YAML-Parameterbibliotheken (`inst/extdata/…`) und (2) Vorschläge für Standardverteilungen der Monte-Carlo-Simulation (MC) des VoFi-Werkzeugs für Neubau und energetische Sanierung von Wohngebäuden in Deutschland.
> **Stichtag** aller Recherchen: 25.10.2026. Jeder Wert trägt Quelle, Datenstand und Qualitätsstufe. Wo Werte unsicher oder nur über Sekundärquellen belegt sind, ist das ausdrücklich vermerkt.
> **Perspektiven:** Wohnungsunternehmen (kommunal, genossenschaftlich, privatwirtschaftlich) und Privatpersonen (Selbstnutzer, kleine Vermieter). **Ertragsteuern sind in v1 ausgeklammert** (Vor-Steuer-VoFi).
> **Konvention:** R-Schlüssel englisch `snake_case`, alle Bezeichnungen/Erläuterungen deutsch.

---

## 0. Kurzfassung (Executive Summary)

1. **2026 ist ein Krisenjahr für Energiepreise.** Der Iran-Krieg / die Blockaden in der Straße von Hormus haben Heizöl stark verteuert (VPI Heizöl Sept. 2026: +74,9 % ggü. Vorjahr; Portalpreise ca. 171–174 €/100 l am 19.–25.10.2026), Gas zieht im Großhandel an, Neukundentarife folgen verzögert. Strom ist 2026 durch den Bundeszuschuss zu den Übertragungsnetzentgelten gesunken. → **Startwerte nicht stumpf aus Spotpreisen ableiten**: Empfehlung 12-Monats-Mittel als Default, Spotwert als Alternative, im MC ein mean-reverting Preismodell um einen „Normalpreis“.
2. **CO₂-Preis explizit getrennt modellieren** (nicht im Energiepreis „verstecken“): BEHG 2026 Korridor 55–65 €/t (erste Versteigerung 01.07.2026 bei 65 €/t), 2027 laut Kabinettsentwurf erneut 55–65 €/t (Gesetzgebung läuft), ab 2028 EU-ETS 2. Drei Korridore (niedrig/mittel/hoch); „hoch“ = UBA-Rahmendaten Projektionen 2026 (125 €/t 2030, 200 €/t 2035, 350 €/t 2045, nominal).
3. **Zinsen sind 2026 gestiegen:** EZB-Einlagesatz 2,25 % (ab Juni) → 2,50 % (ab Sept. 2026); 10-j. Bundrendite (Svensson) Sept. 3,64 %, 23.10.2026 3,39 %; Effektivzins Wohnungsbaukredite >10 J. Zinsbindung Aug. 2026 4,04 % (Bundesbank). Default Bauzins 10 J.: **4,1 %**.
4. **Inflation:** VPI Sept. 2026 +3,3 %; Prognosen 2026 ≈ 2,9–3,0 %, 2027 ≈ 2,5–2,7 %, 2028 ≈ 1,9–2,1 %; langfristig 2,0 %.
5. **Baukosten:** Geschosswohnungsneubau in Großstädten Q4/2025 Median Herstellungskosten (KG 200–700, brutto) 4.631 €/m² Wfl., Bauwerkskosten (KG 300+400) Median im Intervall 3.500–3.750 €/m² Wfl. (ARGE e. V. 2026). Baupreise Wohngebäude Aug. 2026 +5,5 % ggü. Vorjahr. Default Neubau MFH KG 300+400 2026: **3.750 €/m² Wfl.**
6. **Sanierungskosten bottom-up** über die IWU-Kostenfunktionen (Preisstand 2023, hier auf 2026 mit Faktor 1,12 fortgeschrieben), z. B. WDVS 16 cm ≈ 248 €/m² Bauteilfläche Vollkosten, davon ≈ 119 €/m² energiebedingte Mehrkosten (Ohnehin-Anteil ≈ 52 %).
7. **Bewirtschaftungskosten 2026 sind amtlich fortgeschrieben:** II. BV ab 01.01.2026: Verwaltung 372,46 €/WE·a, Instandhaltung 11,50 / 14,58 / 18,62 €/m²·a (<22 / ≥22 / ≥32 Jahre); ImmoWertV-Modellwerte 2026: Verwaltung 367 €/WE, Instandhaltung 14,4 €/m², Mietausfallwagnis 2 %.
8. **Rechtsrahmen im Umbruch:** Das GEG heißt seit dem Änderungsgesetz vom 23.07.2026 (BGBl. 2026 I Nr. 226) **Gebäudemodernisierungsgesetz (GModG)**; erste Stufe seit 29.07.2026 in Kraft, weitere Teile (u. a. neue Primärenergie- und Emissionsfaktoren, Referenzgebäude) ab 01.01.2027. **Emissionsfaktoren nach Anlage 9 (GEG-Werte) gelten nur noch bis 31.12.2026** – Bibliothek muss Gültigkeitszeiträume (`valid_from`/`valid_to`) tragen.
9. **Wohnungsunternehmen ohne Vorsteuerabzug:** Wohnraumvermietung ist umsatzsteuerfrei (§ 4 Nr. 12 UStG) → Bau-, Sanierungs- und Energiekosten sind **brutto** anzusetzen. Netto-Preise nur für gewerbliche Teile/Optionsfälle.
10. **Historische Volatilität (jährliche Log-Änderungen 2001–2025, HVPI-Teilindizes DE):** Strom σ ≈ 4,8 %, Gas σ ≈ 10,2 %, Heizöl σ ≈ 20,1 %, Fernwärme σ ≈ 8,2 %, feste Brennstoffe (inkl. Pellets) σ ≈ 9,3 %, VPI σ ≈ 1,7 %-Pkt. Die Korrelationen sind stark von 2022/23 geprägt → im MC geschrumpfte Korrelationen verwenden.

---

## 1. Methodik, Konventionen, Qualitätsstufen

### 1.1 Konventionen
| Aspekt | Festlegung |
|---|---|
| Preisbasis | nominal, EUR des jeweiligen Jahres; Startjahr 2026. Reale Größen werden mit VPI deflationiert. |
| Umsatzsteuer | Private: brutto (inkl. 19 % USt; PV ≤ 30 kWp: 0 %). Wohnungsunternehmen (Wohnraum): **brutto**, da kein Vorsteuerabzug. Netto-Werte werden als Hilfsgröße mitgeführt (`*_net`). |
| Energiebezug | Erdgas: bezogen auf **Brennwert Hs** (Abrechnungsgröße); Heizöl/Pellets: **Heizwert Hi**; Umrechnung Erdgas Hs→Hi Faktor 0,903 (EBeV 2030, Anlage 2). Emissionsfaktoren nach GEG/GModG Anlage 9 beziehen sich auf Endenergie nach DIN V 18599 (Hi-Basis) – im Code konsistent umrechnen. |
| Flächenbezug | Wohnfläche (Wfl.) nach WoFlV, außer explizit Bauteilfläche, Gebäudenutzfläche A_N (≈ 1,2–1,35 × Wfl.) oder Dachfläche. |
| Zeitauflösung | Jahresschritte (Vorschlag); Monatswerte nur für Startwert-Ermittlung. |
| MC-Verteilungen | `triangular(min, mode, max)` für Expertenspannen; `normal`/`lognormal` für statistisch geschätzte Größen; Pfadmodelle (AR(1)/OU, Vasicek) für Zeitreihen. |

### 1.2 Qualitätsstufen (Feld `quality` im YAML)
| Stufe | Bedeutung |
|---|---|
| **A** | Amtliche/primäre Quelle, Originaldokument oder Datenbank-API selbst geprüft (z. B. Bundesbank-API, Eurostat, Gesetzestext, BNetzA-Monitoringbericht, UBA). |
| **B** | Verbands-/Institutsstudie im Original geprüft (BDEW, ARGE e. V., IWU, GdW, Gutachterausschuss). |
| **C** | Nur über Sekundärquelle/Pressebericht/Websuche belegt, Original nicht eingesehen. |
| **D** | Eigene Ableitung/Expertenschätzung aus mehreren Quellen. |

### 1.3 Wie aus Recherche Defaults und Verteilungen werden
- **Deterministischer Default (`value`)** = bester Schätzwert für Projektstart 2026 (bei volatilen Energiepreisen: 12-Monats-Mittel bzw. Jahresmittel 2026, nicht Spot).
- **MC-Verteilung (`dist`)** = Unsicherheit des Startwerts bzw. des Parameters (Parameterunsicherheit), getrennt von der **stochastischen Pfaddynamik** (`dynamics`), die zeitliche Schwankungen erzeugt.
- **Szenarien (`scenarios`)** = deterministische Alternativpfade (z. B. CO₂-Preis niedrig/mittel/hoch) für Sensitivitäts- und Szenarioanalysen.

### 1.4 Eigene Auswertungen (Reproduzierbarkeit)
Folgende Kennzahlen wurden am 25.10.2026 aus offenen Datenschnittstellen berechnet (Python, Skripte im Scratchpad, nicht im Repo):
- Eurostat `prc_hicp_aind` (HVPI, Jahresdurchschnitte, DE, 1996–2025; Datenstand 06.02.2026) – Teilindizes CP00, CP041, CP0432, CP044, CP0451–CP0455.
- Eurostat `sts_copi_a` (Baupreise neue Wohngebäude, DE, 2021=100; Datenstand 26.09.2026).
- Deutsche Bundesbank Zeitreihen-API (`api.statistiken.bundesbank.de`): BBIM1 (MFI-Zinsstatistik), BBSIS (Zinsstruktur Svensson), BBIN1 (EZB-Zinsen), BBDP1 (VPI).
Hinweis: Die Eurostat-HVPI-Jahresreihe endet 2025 (Datenstand Feb. 2026); 2026er Werte stammen aus Destatis-Pressemitteilungen.

---

## 2. Energiepreise

### 2.1 Aktuelle Preisniveaus 2026 – Privathaushalte (brutto)

| Schlüssel | Energieträger | Default 2026 | Spanne (min / Modus / max) | Referenzwerte & Quellen | Volatilität / Hinweis |
|---|---|---|---|---|---|
| `price_gas_household` | Erdgas EFH (Hs) | **12,0 ct/kWh** | 10,5 / 12,0 / 15,5 | BDEW: Ø 2026 bisher 11,93 ct (EFH, 20.000 kWh, Neukundentarife), MFH 11,17 ct; Aug. 2026 12,45 ct [Q02, Q06]; Destatis Ø aller Haushalte 1. Hj 2026: 11,58 ct [Q03, C]; BNetzA mengengewichtet 01.04.2025: 12,13 ct [Q05]; Verivox (günstigster Anbieter, 20.000 kWh) 14.09.2026: 12,2 ct [Q11, C]; Verivox erwartet bis +20 % zum Jahreswechsel [Q11, C] | hoch; Aufwärtsrisiko 2027 durch Großhandel (TTF Q3/2026 ≈ 50–60 €/MWh lt. Goldman/OIES-Berichten [Q51, C]) |
| `price_gas_household_mfh` | Erdgas je Partei im MFH (Hs) | 11,2 ct/kWh | 9,8 / 11,2 / 14,5 | BDEW MFH 6 Parteien à 13.333 kWh: 11,17 ct (2026 bisher) [Q02] | wie oben |
| `price_heating_oil` | Heizöl EL (Hi) | **14,0 ct/kWh** (≈ 140 €/100 l) | 9,5 / 14,0 / 19,0 | Spot 19.–25.10.2026: 171–174 €/100 l ≈ 17,1–17,4 ct/kWh [Q08, C]; Juli 2026: 14,06 ct (Destatis-Basis, lt. [Q06]); Ø 2025 ≈ 90–95 €/100 l ≈ 9,3 ct (Portalwerte, [Q08, C]); VPI Heizöl Sept. 2026 +74,9 % [Q04] | **sehr hoch**; Default = grobes 12-Monats-Mittel (Nov. 2025–Okt. 2026), Spotwert als Alternative `price_heating_oil_spot` |
| `price_district_heating` | Fernwärme (Mischpreis inkl. Grund-/Messpreis) | **15,6 ct/kWh** | 12,5 / 15,6 / 17,5 (Extrema 8–36) | waermepreise.info (AGFW/BDEW/VKU), gewichteter Mischpreis MFH 01.04.2026: 15,6 ct brutto [Q06]; mengengewichtet 01.01.2026: 15,7 ct [Q07]; Spanne Netze Jan. 2026: ~8 (Mücheln) bis 36 ct (Seelow) [Q07] | mittel; stark netzspezifisch → Nutzer soll lokalen Preis eintragen |
| `price_electricity_household` | Haushaltsstrom | **37,5 ct/kWh** | 32 / 37,5 / 42 | BDEW 2026: 37,0 ct (3.500 kWh, Neukunden; Beschaffung/Vertrieb 15,17, Netz 9,24, Steuern/Abgaben 12,6) [Q01]; Destatis 1. Hj 2026: 37,97 ct [Q03, C]; BNetzA 01.04.2025 mengengewichtet: 40,05 ct [Q05] | mittel; Netzentgeltzuschuss 2026 (–1,7 ct) politisch, Fortführung unsicher |
| `price_electricity_heatpump` | Wärmepumpenstrom (separater Zähler, §14a) | **26,0 ct/kWh** | 20 / 26 / 31 | BNetzA 01.04.2025: WP getrennte Messung 27,44 ct, gemeinsame Messung 31,70 ct, Nachtspeicher 28,47 ct (mengengewichtet, 7.500 kWh) [Q05]; günstigster Neukundentarif 2026 lt. Verivox ≈ 20,7 ct [Q39, C] | mittel; Default = Bestandsniveau abzüglich Netzentgeltsenkung 2026 (D) |
| `price_wood_pellets` | Holzpellets (Hi, 5,0 kWh/kg, 6 t) | **8,5 ct/kWh** (≈ 425 €/t) | 6,5 / 8,5 / 10,5 | DEPI Okt. 2026: 464,61 €/t = 9,29 ct/kWh (26 t: 443–451 €/t) [Q09, C]; Jahresmittel 2025: 343,01 €/t ≈ 6,9 ct [Q10, C]; 2021: 241 €/t [Q10, C] | hoch; Holzmarkt angespannt (Sägeresthölzer knapp); USt 19 % seit 2024 |

**Hinweise zu Heizöl/Gas 2026:** Destatis meldet für Sept. 2026: Energie insgesamt +14,9 %, Heizöl +74,9 %, Brennholz/Pellets/feste Brennstoffe +15,6 %, Strom −5,5 %, Erdgas −2,8 %, Fernwärme −1,0 % ggü. Vorjahresmonat (VPI 2020=100: 126,6) [Q04]. Gas- und Fernwärme-Endkundenpreise reagieren mit 3–12 Monaten Verzögerung auf Großhandelspreise; für 2027 ist ein Anstieg wahrscheinlich.

### 2.2 Preise für Wohnungsunternehmen (Hilfsgrößen, netto ohne USt)
Da Wohnungsunternehmen für Wohnraum keinen Vorsteuerabzug haben, sind die Bruttowerte maßgeblich. Netto-Werte dienen für gewerbliche Einheiten, Mieterstrom-/Contracting-Modelle oder Unternehmen mit USt-Option.

| Schlüssel | Größe | Default netto | Spanne | Herleitung |
|---|---|---|---|---|
| `price_gas_company_net` | Erdgas Zentralheizung MFH (80–500 MWh/a), Hs | 9,4 ct/kWh | 7,5–12,0 | BDEW MFH 11,17 ct brutto / 1,19 [Q02], D |
| `price_district_heating_company_net` | Fernwärme MFH | 13,1 ct/kWh | 10,5–14,7 | 15,6 ct / 1,19 [Q06], D |
| `price_electricity_common_net` | Allgemeinstrom (Treppenhaus, Aufzug) | 27,0 ct/kWh | 22–33 | BDEW Haushalt netto ≈ 31,1 ct; Gewerbe-Kleinverbrauch etwas günstiger, D |
| `price_electricity_heatpump_company_net` | WP-Strom Zentral-WP MFH | 21,0 ct/kWh | 17–26 | BNetzA 27,44 ct brutto / 1,19 ≈ 23,1 ct; Mengenrabatt, D |

Zum Vergleich Industrie/Gewerbe (Mittelspannung, 160 MWh–20 GWh): Strom 2026 bisher 17,2 ct/kWh netto [Q01]; Gas (5–50 GWh) 2026 ≈ 6,8 ct/kWh [Q02] – für Wohnungswirtschaft i. d. R. nicht einschlägig.

### 2.3 Historische Volatilität (eigene Auswertung, HVPI DE)

**Jährliche Log-Änderungen der Preisindizes (nominal), 2001–2025** [Q12, A]:

| Index | Ø Log-Änderung (≈ CAGR) | σ jährlich | min / max | Ø real (über VPI) | σ real | AR(1) der Änderungen |
|---|---|---|---|---|---|---|
| VPI/HVPI gesamt (CP00) | 2,06 % | 1,74 %-Pkt | 0,2 % / 8,3 % | – | – | 0,53 |
| Strom (CP0451) | 4,07 % (4,15 %) | 4,81 % | −6,6 % / +18,3 % | +2,01 % | 3,96 % | 0,15 |
| Gas (CP0452) | 4,58 % (4,69 %) | 10,23 % | −8,9 % / +38,7 % | +2,53 % | 8,89 % | 0,26 |
| Heizöl (CP0453) | 2,47 % (2,51 %) | 20,09 % | −36,6 % / +53,2 % | +0,42 % | 19,08 % | 0,05 |
| Feste Brennstoffe inkl. Pellets (CP0454) | 2,70 % | 9,25 % | −12,5 % / +43,3 % | +0,65 % | 7,99 % | 0,09 |
| Fernwärme (CP0455) | 4,84 % (4,96 %) | 8,19 % | −8,8 % / +24,0 % | +2,79 % | 7,34 % | 0,20 |

Teilzeiträume (σ nominal): 2000–2020 Strom 2,7 %, Gas 6,8 %, Heizöl 18,5 %, feste Brennstoffe 2,2 %, Fernwärme 6,8 %; 2010–2025 Strom 6,2 %, Gas 11,3 %, Heizöl 21,0 %, feste Brennstoffe 12,1 %, Fernwärme 8,5 %. → Die Volatilität von Strom, Gas und Holz ist seit 2021 strukturell höher.

**Mean-Reversion der realen Log-Preisniveaus** (AR(1) mit Trend, 1996–2025, eigene Schätzung; kleine Stichprobe, daher nur Größenordnung):

| Träger | φ (AR(1)) | κ = −ln φ | Halbwertszeit | σ Residuum | impliziter realer Trend |
|---|---|---|---|---|---|
| Strom | 0,75 | 0,28 | 2,4 J. | 0,038 | +2,1 %/a |
| Gas | 0,79 | 0,24 | 2,9 J. | 0,081 | +1,9 %/a |
| Heizöl | 0,71 | 0,35 | 2,0 J. | 0,182 | +0,9 %/a |
| feste Brennstoffe | 0,48 | 0,73 | 1,0 J. | 0,063 | +0,8 %/a |
| Fernwärme | 0,81 | 0,22 | 3,2 J. | 0,070 | +2,0 %/a |

Die realen Trends 1996–2025 enthalten Steuer-/Abgabenerhöhungen (Ökosteuer, EEG-Umlage bis 2022, CO₂-Preis ab 2021) – sie sind **nicht** als Zukunftstrend zu übernehmen, wenn der CO₂-Preis separat modelliert wird.

**Korrelation der jährlichen Änderungen 2001–2025** (nominal; stark durch 2022/23 geprägt) [Q12, Q13, Q22, A]:

|  | VPI | Gas | Öl | Strom | FW | Holz | Bau | Miete | Instandh. | ΔBund10 |
|---|---|---|---|---|---|---|---|---|---|---|
| VPI | 1 | 0,80 | 0,61 | 0,63 | 0,57 | 0,77 | 0,88 | 0,39 | 0,83 | 0,78 |
| Gas | | 1 | 0,48 | 0,68 | 0,70 | 0,73 | 0,66 | 0,06 | 0,60 | 0,58 |
| Öl | | | 1 | 0,44 | 0,33 | 0,57 | 0,49 | −0,09 | 0,28 | 0,34 |
| Strom | | | | 1 | 0,22 | 0,83 | 0,53 | −0,18 | 0,46 | 0,51 |
| Fernwärme | | | | | 1 | 0,29 | 0,35 | 0,19 | 0,40 | 0,32 |
| Holz/feste | | | | | | 1 | 0,75 | 0,03 | 0,55 | 0,58 |
| Baupreise | | | | | | | 1 | 0,45 | 0,86 | 0,75 |

**Empfehlung für den MC:** Korrelationsmatrix der Innovationen um ca. 30–40 % in Richtung 0 schrumpfen (Shrinkage), weil n = 25 und ein Einzelereignis (2022) dominiert; Vorschlag siehe YAML (`correlation_innovations`), positive Definitheit im Code prüfen (`Matrix::nearPD`).

### 2.4 Preisentwicklungs-Szenarien und stochastisches Modell

**Empfohlenes Preismodell je Energieträger i** (Jahresschritte):
`P_i(t) = [B_i(t) + CO2(t) · EF_i] · (1 + USt)`, mit Basispreis ohne CO₂
`ln B_i(t) = ln B̄_i + g_i · t + ln CPI(t)/CPI(0) + x_i(t)`, `x_i(t) = φ_i · x_i(t−1) + ε_i(t)`, `ε ~ N(0, Σ)`.

- `B̄_i` = „Normalpreis“ (Anker, real 2026, ohne CO₂). `x_i(0) = ln(Startpreis_ohne_CO2 / B̄_i)` bildet die aktuelle Krisenabweichung ab und baut sich mit Halbwertszeit 2–3 Jahre ab.
- `g_i` = realer Trend des Basispreises; im MC je Pfad gezogen (Parameterunsicherheit), z. B. `normal(mean, sd)`.
- CO₂-Komponente nur für fossile Brennstoffe mit BEHG-/ETS2-Pflicht (Gas, Heizöl, Flüssiggas); Fernwärme und Strom tragen ETS-1-Kosten implizit im Basispreis.

**Normalpreise (Anker, real 2026, brutto, ohne CO₂-Komponente) – D (Expertenschätzung):**

| Träger | Startwert 2026 inkl. CO₂ | CO₂-Anteil bei 65 €/t (brutto) | Startwert ohne CO₂ | Normalpreis B̄ (ohne CO₂) | Spanne B̄ | Begründung |
|---|---|---|---|---|---|---|
| Erdgas (Hs) | 12,0 | 1,40 | 10,6 | 10,0 | 8,5–12,0 | 2025/H1 2026 ≈ 11,6–12,2 ct inkl. CO₂ 55–65 €/t; Gasspeicherumlage 2026 entfallen; UBA-Rahmendaten: Großhandel real 45 (2025) → 21 €/MWh (2030) [Q14] |
| Heizöl (Hi) | 14,0 | 2,06 | 11,9 | 8,0 | 6,5–10,5 | Ø 2025 ≈ 9,3 ct inkl. CO₂ 55 €/t (≈ 1,74 ct) → ≈ 7,6 ct; UBA: Brent real 41 → 38 €/MWh (2030) [Q14] |
| Fernwärme | 15,6 | (implizit) | 15,6 | 15,0 | 12,5–17,5 | AGFW 15,7–15,8 ct 2025/26 [Q07] |
| Haushaltsstrom | 37,5 | – | 37,5 | 36,0 | 30–42 | BDEW-Reihe, Netzentgeltzuschuss [Q01] |
| WP-Strom | 26,0 | – | 26,0 | 25,0 | 20–30 | BNetzA [Q05] |
| Pellets (Hi) | 8,5 | – | 8,5 | 7,0 | 5,5–9,0 | Ø 2025 6,9 ct; 2021 4,8 ct [Q10] |

**Deterministische Szenarien für den realen Trend `g_i` des Basispreises (ohne CO₂), % p. a.** (D):

| Träger | niedrig | mittel (Default) | hoch | Anmerkung |
|---|---|---|---|---|
| Erdgas | −1,0 | 0,0 | +1,5 | niedrig ≈ UBA-Großhandelspfad; hoch ≈ dauerhaft LNG-Abhängigkeit, steigende Netzentgelte bei sinkender Abnahme (Netzkosten-Spirale) |
| Heizöl | −1,0 | 0,0 | +1,5 | wie Gas; zusätzlich Grünheizölquote ab 2028 (§ 42a GModG, Höhe offen) |
| Strom (Haushalt/WP) | −0,5 | 0,0 | +1,0 | Netzausbau vs. EE-Kostendegression; Zuschüsse politisch |
| Fernwärme | 0,0 | +0,5 | +2,0 | Transformationskosten Wärmenetze, Preisgleitklauseln |
| Pellets | 0,0 | +0,5 | +1,5 | Holzknappheit vs. Kapazitätsausbau |

Zusätzlich empfohlen: **Bio-Treppe/Grüngasquote** als Aufschlag auf Gas/Öl für neu eingebaute fossile Kessel (GModG: ab 2029 10 %, 2030 15 %, 2035 30 %, 2040 60 % biogene/klimaneutrale Brennstoffe [Q19]) – Mehrkostenfaktor gegenüber fossil z. B. Biomethan +4–8 ct/kWh (Expertenschätzung D; eigene Recherche erforderlich).

---

## 3. CO₂-Preise und Emissionsfaktoren

### 3.1 BEHG (nationaler Emissionshandel)

| Jahr | Preis | Status / Quelle |
|---|---|---|
| 2021 | 25 €/t | Festpreis BEHG [Q14] |
| 2022 | 30 €/t | Festpreis [Q14] |
| 2023 | 30 €/t | Festpreis (Erhöhung ausgesetzt) [Q14] |
| 2024 | 45 €/t | Festpreis [Q14] |
| 2025 | 55 €/t | Festpreis [Q14] |
| 2026 | Korridor 55–65 €/t; 1. Versteigerung 01.07.2026: **65 €/t** (Obergrenze) | DEHSt lt. [Q06]; Nachkauf außerhalb Versteigerungsmenge 68 €/t (Erwerb 2026) bzw. 70 €/t (Erwerb 2027) nach BEHV-Novelle 16.09.2025 [Q14]; lt. BEHG-Kabinettsentwurf 75/73 €/t für Nachkauf-/Überschussmengen [Q18, C] |
| 2027 | Korridor 55–65 €/t (Kabinettsbeschluss 12.08.2026, 1. Lesung BT 24.09.2026; **noch nicht in Kraft**) | Drittes BEHG-Änderungsgesetz, BR-Drs. 462/26 [Q18] |
| ab 2028 | EU-ETS 2 (BEHG-Abgabepflicht entfällt für ab 01.01.2028 in Verkehr gebrachte Brennstoffe) | [Q18], [Q16] |

### 3.2 EU-ETS 2 – Design (Stand Okt. 2026)
- Start 2028 statt 2027 (Beschluss Umweltrat Nov. 2025; vom Rat am 05.03.2026 final bestätigt lt. [Q06]).
- Preisstabilitätsmechanismus (Art. 30h RL 2003/87/EG): absoluter Auslöser 45 €/t **in Preisen von 2020** (≈ 56 €/t nominal 2027) für ≥ 2 Monate → Freigabe aus der MSR [Q15]. Reform (vorläufige Einigung Rat/EP 11.06.2026; lt. Websuche vom Rat am 09.10.2026 endgültig angenommen): Freigabemenge bei Überschreiten von 45 €/t verdoppelt von 20 auf 40 Mio. Zertifikate, Gültigkeit der MSR-Zertifikate über 2030 hinaus, frühere schrittweise Freigabe, wenn Umlaufmenge < 260 Mio. [Q16; Ratsbeschluss C].
- Relative Preisauslöser (150 % / 200 % / 300 % des gleitenden Durchschnitts) wurden in UBA-Modellläufen nie ausgelöst [Q15].
- Modellierungsbefund UBA/Veyt: Alle Reformoptionen senken den ETS2-Preis ggü. Basisfall, bis −24 % (2027) und −68 % (2032) im Szenario „Longer Effectiveness“ [Q15].

### 3.3 Projektionen/Prognosen ETS2 (nominal, €/t)

| Quelle | 2028 | 2030 | 2032 | 2035 | 2040 | 2045 | 2050 | Anmerkung |
|---|---|---|---|---|---|---|---|---|
| **UBA Rahmendaten Projektionen 2026** (Prognos, Apr. 2026) [Q14, A] | 95 | 125 | 155 | 200 | 275 | 350 | 425 | +15 €/t p. a. ab 2027; real (EUR2024): 84 / 106 / 125 / 152 / 191 / 224 / 251; bewusst ohne 2027er Korridor-Beschluss |
| Analysten (Carbon Pulse, Okt. 2026) [Q17, C] | ≈ 50 | – | ≈ 90 | – | – | – | – | Erwartung nach Reform; erste Auktion 18.01.2027 (Frontloading) |
| Analysten (Carbon Pulse, Apr. 2026) [Q17, C] | – | – | – | Peak 132 | – | – | – | unter Reformvorschlägen |
| EU-Kommission (ETS2-Annahme) [Q14, C] | – | ≈ 45–55 (EUR2020/24) | – | – | – | – | – | „Gleichgewichtspreis“, unterhalb nEHS-Niveau |
| Meta-Analyse Hochschule Niederrhein (Gerlach-Günsch 2024) [Q14] | – | 51–384 (EUR2023) | – | – | – | – | – | Bandbreite der Studien |
| Ariadne/REMIND (Fit-for-55 ohne ETS-Entlastung) [C] | – | 275 (210–405) | – | – | – | – | – | Stress-Szenario, vor Reform/Verschiebung |
| ETS 1 (zum Vergleich, UBA, EUR2024 real) [Q14] | – | 84 | – | 144 | 174 | 187 | 199 | für Strom/Fernwärme indirekt relevant |

### 3.4 Empfohlene CO₂-Korridore für das Tool (nominal, €/t; D)

| Jahr | `low` | `mid` (Default) | `high` (= UBA 2026) |
|---|---|---|---|
| 2026 | 65 | 65 | 65 |
| 2027 | 55 | 65 | 80 |
| 2028 | 45 | 60 | 95 |
| 2030 | 55 | 75 | 125 |
| 2032 | 60 | 90 | 155 |
| 2035 | 75 | 130 | 200 |
| 2040 | 100 | 170 | 275 |
| 2045 | 120 | 210 | 350 |
| 2050 | 140 | 250 | 425 |

- `low`: Preisdämpfung durch MSR/PSM wirkt dauerhaft; Preis nahe 45 €₂₀₂₀ zuzüglich Inflation.
- `mid`: Analystenerwartung nach Reform (≈ 50–60 €/t 2028, ≈ 90 €/t 2032, ≈ 130 €/t 2035), danach Verknappung durch sinkendes Cap (eigene Extrapolation).
- `high`: Pfad der amtlichen THG-Projektionen 2026.
- **MC-Vorschlag:** Je Pfad ein Quantil `u ~ U(0,1)` ziehen und für alle Stützjahre die Dreiecksverteilung (low, mid, high) mit demselben `u` auswerten (komonotone Ziehung → konsistente Pfade), linear interpolieren; optional zusätzlicher jährlicher Lärmterm σ = 10 %.
- Kosten je kWh bei 65 €/t: Erdgas 1,18 ct netto / 1,40 ct brutto je kWh (Hs); Heizöl 1,73 / 2,06 ct je kWh (Hi) bzw. ≈ 17,4 / 20,7 ct je Liter; je +10 €/t: Gas +0,22 ct, Heizöl +0,32 ct brutto/kWh.

### 3.5 Emissionsfaktoren nach GEG/GModG Anlage 9 (g CO₂-Äq./kWh Endenergie) [Q19, A]
Gültig in dieser Fassung bis 31.12.2026 (Anlage 9 wird durch das Änderungsgesetz vom 23.07.2026, BGBl. 2026 I Nr. 226, **neu gefasst**; neue Werte ab 01.01.2027 konnten nicht im amtlichen Volltext geprüft werden).

| Energieträger | Faktor | Energieträger | Faktor |
|---|---|---|---|
| Heizöl | 310 | Biogas | 140 |
| Erdgas | 240 | Biogas, gebäudenah | 75 |
| Flüssiggas | 270 | Biogenes Flüssiggas | 180 |
| Steinkohle | 400 | Bioöl | 210 |
| Braunkohle | 430 | Bioöl, gebäudenah | 105 |
| Holz | 20 | Strom netzbezogen | 560 |
| Strom gebäudenah (PV/Wind) | 0 | Verdrängungsstrommix | 860 |
| Erdwärme/Solarthermie/Umgebungswärme | 0 | Abwärme aus Prozessen | 40 |
| Siedlungsabfall-Verbrennung | 20 | KWK gebäudenah | DIN V 18599-9 |
| Nah-/Fernwärme KWK (≥ 70 %): Kohle / Gas-Öl / erneuerbar | 300 / 180 / 40 | Nah-/Fernwärme Heizwerk: Kohle / Gas-Öl / erneuerbar | 400 / 300 / 60 |

Fernwärme mit vom Betreiber veröffentlichtem Faktor: dieser gilt (inkl. Vorkette/Netzverluste, alternativ +20 %, mind. 40 g/kWh).
**Unbestätigte Hinweise auf 2027er Werte** (Sekundärquelle nexvyra.de, ausdrücklich als „offen“ gekennzeichnet): Strom netzbezogen 100 g/kWh (statt 560), Primärenergiefaktor Strom 1,5 (statt 1,8; Wechsel von f_p,ne auf f_p,tot) [Q19b, C]. **Nicht übernehmen, bevor BGBl.-Text geprüft ist.** Für die Wirtschaftlichkeitsrechnung (CO₂-Kosten) sind ohnehin die BEHG-Faktoren maßgeblich (3.6), Anlage 9 nur für Energieausweis/Klassifizierung.

### 3.6 Emissionsfaktoren für die CO₂-Kosten (BEHG/EBeV 2030, Anlage 2) [Q20, A]

| Brennstoff | Emissionsfaktor | je kWh | Hinweis |
|---|---|---|---|
| Erdgas | 0,0558 t CO₂/GJ (Hi); Umrechnung 3,2508 GJ/MWh Hs (= 3,6 × 0,903) | **0,2009 kg/kWh Hi = 0,1814 kg/kWh Hs** | gleiche Werte im CO2KostAufG |
| Heizöl EL | 0,074 t CO₂/GJ; Hi 42,8 GJ/t | **0,2664 kg/kWh Hi** ≈ 2,68 kg/l | Dichte ≈ 0,845 kg/l |
| Flüssiggas (Heizzwecke) | 0,0655 t CO₂/GJ; Hi 46,0 GJ/t | 0,2358 kg/kWh Hi | Verband fordert Anpassung an Propan |
| Holz, Pellets | 0 (bei Nachhaltigkeitsnachweis) | 0 | |
| Fernwärme, Strom | nicht BEHG-pflichtig auf Verbraucherebene | – | ETS 1/BEHG beim Erzeuger, im Preis enthalten |

### 3.7 CO₂-Kostenaufteilung Vermieter/Mieter (CO2KostAufG, Wohngebäude) [Q21, C]

| CO₂-Ausstoß kg/(m² Wfl.·a) | < 12 | 12–<17 | 17–<22 | 22–<27 | 27–<32 | 32–<37 | 37–<42 | 42–<47 | 47–<52 | ≥ 52 |
|---|---|---|---|---|---|---|---|---|---|---|
| Vermieteranteil | 0 % | 10 % | 20 % | 30 % | 40 % | 50 % | 60 % | 70 % | 80 % | 95 % |

**Änderung durch GModG (unsicher):** Laut Kanzlei GÖRG (17.07.2026) werden ab 2028 Erdgas-Netzentgelte und CO₂-Kosten unabhängig vom energetischen Zustand hälftig (50/50) geteilt; Anwendungsbereich offenbar Mietverhältnisse im Bestand nach Heizungstausch, Härtefallklausel für sehr niedrige Mieten; Kosten der ersten Bio-Treppen-Stufen ab 2029 ebenfalls 50/50 [Q19c, B]. → Parameter `co2_cost_split_rule` mit Varianten `stufenmodell_2023` und `haelftig_ab_2028`; Gesetzestext prüfen.

---

## 4. Zinsen

### 4.1 Aktuelle Zinsniveaus (Okt. 2026)

| Schlüssel | Größe | Wert | Stand | Quelle |
|---|---|---|---|---|
| `rate_mortgage_10y_plus` | Effektivzins Wohnungsbaukredite priv. HH, Zinsbindung > 10 J. (Neugeschäft) | 4,04 % | Aug. 2026 | Bundesbank SUD119 [Q22, A] |
| – | dto. Zinsbindung 5–10 J. | 3,81 % | Aug. 2026 | SUD118 |
| – | dto. 1–5 J. | 4,03 % | Aug. 2026 | SUD117 |
| – | dto. variabel/≤ 1 J. | 4,40 % | Aug. 2026 | SUD116 |
| – | Effektiver Jahreszins einschl. Kosten (alle Wohnungsbaukredite) | 4,05 % | Aug. 2026 | SUD131 |
| – | Top-Bauzins 10 J., 2 % Tilgung (Vermittler) | ab 4,16 % (13.10.2026); Anstieg im Sept. von ≈ 3,75 % auf ≈ 4,25 % | Okt. 2026 | Dr. Klein [Q24, C] |
| `rate_company_loan_long` | Kredite an nichtfin. Unternehmen 0,25–1 Mio. €, Zinsbindung > 10 J. | 3,86 % (besichert 3,24 %) | Aug. 2026 | SUD148 / SUD173 [Q22, A] |
| – | dto. 5–10 J. | 4,24 % (besichert 4,07 %) | Aug. 2026 | SUD147 / SUD172 |
| `rate_overdraft_company` | Revolvierende Kredite/Überziehung nichtfin. Unternehmen | 5,08 % | Aug. 2026 | SUD123 |
| `rate_overdraft_household` | dto. private Haushalte (Dispo) | 9,46 % | Aug. 2026 | SUD112 |
| `rate_deposit_overnight` | Einlagen priv. HH täglich fällig (Ø Bestand Neugeschäft) | 0,51 % (Unternehmen 0,81 %) | Aug. 2026 | SUD101 / SUD107 |
| `rate_deposit_1y` | Einlagen priv. HH Laufzeit ≤ 1 J. | 2,28 % (Unternehmen 2,25 %) | Aug. 2026 | SUD102 / SUD108 |
| – | Einlagen priv. HH 1–2 J. / > 2 J. | 2,64 % / 2,72 % | Aug. 2026 | SUD103 / SUD104 |
| `yield_bund_10y` | Bundesanleihe 10 J. (Svensson-Nullkupon) | 3,39 % (23.10.2026); Monatsmittel Sept. 3,64 % | Okt. 2026 | BBSIS [Q22, A] |
| `yield_bund_5y` / `yield_bund_1y` | 5 J. / 1 J. | 3,36 % / 3,04 % | Sept. 2026 | BBSIS |
| `ecb_deposit_rate` | EZB-Einlagefazilität | 2,50 % (seit Sept. 2026; 2,25 % ab Juni 2026; 2,00 % bis Mai 2026) | Sept. 2026 | BBIN1 [Q22, A] |

**KfW-Konditionen (Maximalzinssätze, Auszahlung 100 %; Stand Konditionenanzeiger 22.10.2026) [Q23, A]:**

| Programm | Laufzeit / tilgungsfrei / Zinsbindung | Sollzins (Effektivzins) |
|---|---|---|
| 261 BEG WG Kredit Effizienzhaus | 10/2/10 · 20/3/10 · 30/5/10 | 3,01 (3,05) · 3,53 (3,59) · 3,65 (3,71) % |
| 297/298 Klimafreundlicher Neubau – Standard | 10/2/10 · 25/3/10 · 35/5/10 | 1,94 (1,96) · 2,81 (2,85) · 2,94 (2,98) % |
| 297/298 – Variante EH 55 (gültig ab 10.04.2026) | 10/2/10 · 25/3/10 · 35/5/10 | 1,00 (1,00) · 2,03 (2,05) · 2,19 (2,21) % |
| 300/308 Wohneigentum für Familien | 25/3/10 · 35/5/10 | 0,72 (0,72) · 1,00 (1,00) % |
| 124 Wohneigentumsprogramm | 25/3/10 · 35/5/10 | 4,54 (4,64) · 4,56 (4,66) % |
| 159 Altersgerecht Umbauen | 20/3/10 · 30/5/10 | 3,88 (3,95) · 3,96 (4,03) % |
| 358 BEG EM Ergänzungskredit Plus (einkommensabh.) | 25/3/10 · 35/5/10 | 2,53 (2,56) · 2,68 (2,71) % |
| 359 BEG EM Ergänzungskredit | 25/3/10 · 35/5/10 | 4,62 (4,72) · 4,63 (4,73) % |

KfW-Zinsen ändern sich teils wöchentlich → nur als Momentaufnahme; Förderlogik (Tilgungszuschüsse, BEG-Zuschüsse) gehört in eine eigene Förder-Bibliothek. BEG-Heizungsförderung (KfW 458) wurde zum 21.07.2026 neu geordnet (u. a. einkommensabhängig, Familienbonus, niedrigere Höchstförderung) [Q19c; Details C].

### 4.2 Historisches Verhalten (eigene Auswertung Bundesbank-Daten) [Q22, A]

Jahresmittel (Auszug), %:

| Jahr | 1990 | 1995 | 2000 | 2005 | 2008 | 2010 | 2012 | 2014 | 2016 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 | Aug./Sep. 2026 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Bund 10 J. | 8,80 | 7,12 | 5,35 | 3,45 | 4,16 | 2,97 | 1,65 | 1,23 | 0,07 | −0,25 | −0,52 | −0,30 | 1,27 | 2,46 | 2,40 | 2,68 | 3,64 (Sept.) |
| Wohnungsbaukredit > 10 J. | – | – | – | 4,35 | 5,04 | 3,98 | 3,20 | 2,64 | 1,80 | 1,53 | 1,22 | 1,26 | 2,65 | 3,80 | 3,56 | 3,65 | 4,04 (Aug.) |
| Festgeld HH ≤ 1 J. | – | – | – | 1,91 | 4,13 | 1,10 | 1,16 | 0,58 | 0,31 | 0,18 | 0,13 | 0,02 | 0,53 | 2,75 | 3,02 | 1,91 | 2,28 (Aug.) |
| Tagesgeld HH | – | – | – | 1,19 | 1,95 | 0,69 | 0,67 | 0,28 | 0,09 | 0,01 | 0,00 | −0,01 | 0,00 | 0,37 | 0,58 | 0,47 | 0,51 (Aug.) |

Statistiken:

| Reihe | Zeitraum | Mittel | min / max | σ der Jahresänderung | AR(1) Jahreswerte φ → κ | θ (Gleichgewicht, geschätzt) | σ (Vasicek, kont.) |
|---|---|---|---|---|---|---|---|
| Bund 10 J. | 1973–2025 | 5,01 % | −0,71 / 11,30 (Monat) | 0,79 Pp | 0,952 → 0,049 | 2,39 % | 0,80 Pp |
| Bund 10 J. | 1990–2025 | 3,62 % | | 0,62 Pp | 0,915 → 0,089 | 1,59 % | 0,61 Pp |
| Bund 10 J. | 2003–2025 | 2,06 % | | 0,64 Pp | 0,886 → 0,121 | 1,39 % | 0,65 Pp |
| Wohnungsbaukredit > 10 J. | 2003–2025 | 3,29 % | 1,11 / 5,38 (Monat) | 0,53 Pp | 0,877 → 0,131 | 2,74 % | 0,54 Pp |
| Bund 1 J. | 1973–2025 | 3,87 % | −0,92 / 13,17 | 1,33 Pp | 0,893 → 0,113 | 2,66 % | 1,36 Pp |

Spreads (Monatswerte): Bauzins (>10 J.) − Bund 10 J.: Mittel 1,21 Pp (σ 0,40; min 0,37, max 2,13; seit 2015 Ø 1,43); aktuell (Aug. 2026) nur 0,67 Pp. Festgeld 1 J. − Bund 1 J.: Mittel +0,34 Pp (σ 0,61), aktuell −0,48 Pp. Kontokorrent Unternehmen − Bund 1 J.: Mittel 3,77 Pp (σ 0,77), aktuell 2,32 Pp.

**Interpretation:** Die geschätzten Gleichgewichtsniveaus θ sind durch den säkularen Zinsrückgang 1980–2020 nach unten verzerrt; die Mean-Reversion-Geschwindigkeit ist gering (Halbwertszeit 5–14 Jahre). Für eine 20–40-jährige VoFi sollte θ normativ gesetzt werden (Realzins r* 0,5–1,0 % + Inflation 2 % + Laufzeitprämie 0–0,5 %).

### 4.3 Empfohlenes Zinsmodell (D)
- **Faktor:** Vasicek (zeitdiskret, jährlich) auf der 10-j. Bundrendite: `r(t+1) = r(t) + κ(θ − r(t)) + σ·ε`, mit **r0 = 3,4 %, θ = 2,8 % (Spanne 2,0–3,5), κ = 0,12 (0,06–0,20), σ = 0,75 Pp (0,55–0,95)**; stationäre Std.-Abw. ≈ 1,5 Pp. Negative Zinsen zulassen (historisch beobachtet), Untergrenze −1 %.
- **Bauzins/Darlehenszins bei Anschlussfinanzierung:** `i_Darlehen = r_Bund10 + s`, Spread `s` als AR(1) mit Mittel 1,0 Pp (0,6–1,5), φ = 0,7, σ = 0,2 Pp; Startwert 0,7 Pp. Für Wohnungsunternehmen (große, besicherte Darlehen) Spread 0,6–0,9 Pp.
- **Habenzins:** `i_Haben = max(0, r_Bund1 + s_H)`, `s_H` Mittel −0,3 Pp; vereinfachend: 1-j. Rendite ≈ 10-j. Rendite − Laufzeitprämie (Ø 1,1 Pp 1973–2025 aus Daten: 5,01 − 3,87).
- **Kontokorrent/Zwischenfinanzierung:** `r_Bund1 + 2,5 Pp` (Unternehmen), Dispo privat `+6 Pp`.
- **Korrelation mit Inflation:** Innovationen ρ ≈ 0,4–0,5 (Rohwert der Änderungen 0,78, geschrumpft).

---

## 5. Inflation, Baupreise, Mieten

### 5.1 Verbraucherpreise
| Größe | Wert | Quelle |
|---|---|---|
| VPI Sept. 2026 | +3,3 % ggü. Vorjahr (Index 126,6; 2020=100); Kerninflation 2,4 %; Nettokaltmieten +1,9 % (tatsächliche +2,3 %) | Destatis PM 364 vom 13.10.2026 [Q04, A] |
| VPI Okt. 2025 / Okt. 2022 / Okt. 2019 | 123,0 / 113,5 / 100,2 | Bundesbank BBDP1 [Q22, A] |
| Prognose Bundesbank (Juni 2026), HVPI DE | 2026: 2,9 %; 2027: 2,7 %; 2028: 1,9 % | [Q25, C] |
| EZB-Stab (Sept. 2026), HVPI Euroraum | 2026: 3,0 %; 2027: 2,5 %; 2028: 2,1 % | [Q25, C] |
| Gemeinschaftsdiagnose Frühjahr 2026, VPI DE | 2026: 2,8 %; 2027: 2,9 % | [Q26, B] |
| HVPI DE 1997–2025 (eigene Auswertung) | Mittel 1,95 %, σ 1,72 Pp; AR(1): φ = 0,55, μ = 2,0 %, σ_ε = 1,47 Pp | [Q12, A] |

**Default:** 2026: 3,0 %; 2027: 2,6 %; 2028: 2,1 %; ab 2029: 2,0 % (Spanne Langfrist 1,5–3,0 %). **MC:** AR(1) mit μ = 2,0 %, φ = 0,55, σ_ε = 1,45 Pp, Startwert 3,0 %; optional fette Schwänze (t-Verteilung, ν = 5).

### 5.2 Baupreise
| Größe | Wert | Quelle |
|---|---|---|
| Baupreisindex Neubau konventionell gefertigter Wohngebäude, Aug. 2026 | +5,5 % ggü. Aug. 2025 (+1,0 % ggü. Mai); Mai 2026: +5,0 % | Destatis über baulinks 09.10.2026 [Q27, C]; Destatis PM 241 [Q27] |
| Gewerke Aug. 2026 | Rohbau +5,4 %, Ausbau +5,7 %, Dachdeckung +7,6 %, Zimmerer +7,2 %, Heizanlagen/WP +5,2 %, WDVS +5,7 %, Elektro +7,2 % | [Q27, C] |
| Instandhaltung Wohngebäude (ohne Schönheitsrep.) | Aug. 2026 +6,0 %; Mai 2026 +5,6 % | [Q27, C] |
| Jahresindex Wohngebäude (2021=100) | 2020: 92,9; 2021: 100; 2022: 116,3; 2023: 126,1; 2024: 129,8; 2025: 133,9 | Eurostat sts_copi_a [Q13, A] |
| Wachstum 2000–2025 / 2000–2020 / 2010–2025 | 3,09 % / 2,00 % / 4,33 % p. a.; σ 3,2 %; real über VPI +0,99 % p. a. (σ 1,9 %); ρ zu VPI 0,88 | eigene Auswertung [Q13, A] |
| ARGE-Bauwerkskostenindex (Typengebäude MFH) | Q4/2025 = 260 (Q1/2000 = 100) vs. Baupreisindex 222 → zusätzlicher Standard-/Anforderungseffekt ≈ +0,6 % p. a. | [Q28, B] |
| HVPI Instandhaltung/Reparatur Wohnung (CP0432) | 2000–2025: +3,67 % p. a. (σ 3,3 %) | [Q12, A] |

**Default:** Baupreissteigerung 2026: 5,0 %; 2027: 3,5 %; langfristig **VPI + 0,75 Pp** (Spanne VPI + 0 … + 2,0 Pp); Instandhaltungskosten langfristig VPI + 1,0 Pp. **MC:** Innovation ρ ≈ 0,7 zu VPI, idiosynkratisches σ ≈ 1,5 Pp.

### 5.3 Mieten
| Größe | Wert | Quelle |
|---|---|---|
| Nettokaltmieten VPI (Bestand) 2000–2025 | +1,35 % p. a. (σ 0,35 Pp); 2010–2025 +1,52 % | HVPI CP041 [Q12, A] |
| GdW-Unternehmen Ø Nettokaltmiete | 2010: 4,86 → 2024: 6,62 €/m² (+2,2 % p. a.); 2024 +3,6 %; Bundesschnitt Bestand (Zensus) 7,60 €/m² | GdW PM 23.06.2025 / Daten & Trends 2025/26 [Q33, B] |
| Wiedervermietung GdW vs. Inserate | GdW-Wiedervermietungsmieten im Schnitt 26 % unter Angebotsmieten | [Q33, B] |
| Angebotsmieten ImmoScout24 Q2/2026 | Bestand 8,97 €/m² (+2,7 % ggü. Vorjahr); Neubau 13,28 €/m² (+1,8 %) | [Q43, C] |
| GREIX-Mietpreisindex (Kiel Institut) Q4/2025 | Angebotsmieten +4,5 % ggü. Vorjahr | [Q43, C] |
| vdp-Index Q4/2025 MFH | Neuvertragsmieten +3,5 %, Kapitalwerte +5,3 % | [Q48, C] |
| Rechtlicher Rahmen (informativ) | Kappungsgrenze 20 % / 15 % in 3 J.; Mietpreisbremse bis 31.12.2029; Modernisierungsumlage 8 % p. a. mit Kappung 3 €/m² (2 €/m² bei Miete < 7 €/m²) in 6 J.; Reform „Mietrecht II“ (u. a. Indexmiet-Deckel 3,5 %) in Arbeit | [Q53, C] |

**Default:** Bestandsmietsteigerung nominal **1,75 % p. a.** (0,5 / 1,75 / 3,0); Neuvertrags-/Marktmiete **2,5 % p. a.** (0 / 2,5 / 5,0). Regionaler Preset-Mechanismus empfohlen (A-Städte höher, Schrumpfungsregionen ≤ 1 %).

---

## 6. Baukosten

### 6.1 Neubau
| Schlüssel | Größe | Default 2026 (brutto) | Spanne | Quelle / Herleitung |
|---|---|---|---|---|
| `cost_newbuild_mfh_kg300_400` | Bauwerkskosten MFH (KG 300+400) je m² Wfl. | **3.750 €/m²** | 3.000 / 3.750 / 5.000 | ARGE e. V.: Median Bauwerkskosten Großstädte Q4/2025 im Intervall 3.500–3.750 €/m² Wfl., nur 2,3 % der Projekte < 3.000, 4,5 % > 5.000 [Q28, B]; Wohnungsbau-Tag 2025: Typengebäude 3.156, Median 3.589, 87,5-%-Perzentil 4.348 €/m² [Q28b, C]; Fortschreibung +4 % auf 2026 (D) |
| `cost_newbuild_mfh_kg200_700` | Herstellungskosten MFH ohne Grundstück (KG 200–700) | **4.800 €/m²** | 3.300 / 4.800 / 8.600 | ARGE: Median Q4/2025 4.631,07 €/m² (+3,5 % ggü. Vorjahr), Spanne ca. 3.200–8.600 [Q28, B] |
| `share_kg700_of_kg300_400` | Baunebenkosten (KG 700) in % der KG 300+400 | **20 %** | 15 / 20 / 25 % | Herleitung aus ARGE-Aufteilung (Herstellungs- minus Bauwerkskosten ≈ 1.000 €/m², davon Großteil KG 700) und üblichen BKI-Anteilen (D) |
| `share_kg200_500_600_of_kg300_400` | Erschließung, Außenanlagen, Ausstattung | 6 % | 3 / 6 / 10 % | D |
| `cost_newbuild_efh_kg300_400` | Bauwerkskosten EFH (KG 300+400) je m² Wfl. | **3.000 €/m²** | 2.300 / 3.000 / 4.000 | Destatis veranschlagte Kosten Wohngebäude 2024 bundesweit > 2.600 €/m² (Bayern ≈ 2.900) [Q49, C]; Ratgeber/BKI-basierte Rechner 2026: 1.850–3.800 €/m² [C]; veranschlagte Kosten unterschätzen tatsächliche Kosten (D) |
| `cost_newbuild_mfh_full_incl_land` | Vollkosten inkl. Grundstück Großstadt (informativ) | 5.400 €/m² | 4.000–7.500 | ARGE-Median „knapp 5.400 €/m²“; daraus wirtschaftliche Kaltmiete > 20 €/m² (23–25 €/m² je nach Modell) [Q28, B] |

Zusatzkosten für Effizienzstandard: EH 40 ggü. GEG/GModG-Mindeststandard (≈ EH 55) typisch +3–8 % der KG 300+400 (D; ARGE verweist auf Studien zu energetischen Standards, Werte nicht extrahiert).

### 6.2 Energetische Einzelmaßnahmen (Bottom-up, IWU-Kostenfunktionen)
Grundlage: IWU Working Paper (Müller/Fiedler/Koch, 08.08.2024): Kostenfunktionen nach Hinz 2015, auf Preisstand **2023 inkl. USt** fortgeschrieben mit gewerkspezifischen Baupreisindizes [Q29, B]. **Fortschreibung auf 2026: Faktor 1,12** (Baupreisindex Wohngebäude 2023→2025 +6,2 %, 2026 ≈ +5 %; Spanne 1,09–1,16) (D). x = Dämmstoffdicke in cm; A_N = Gebäudenutzfläche (≈ 1,2–1,35 × Wfl.).

| Maßnahme | Vollkosten 2026 (€/m² Bauteilfläche) | Energiebedingte Mehrkosten 2026 | Beispiel | Ohnehin-Anteil (Beispiel) |
|---|---|---|---|---|
| WDVS Außenwand | 169,6 + 4,92·x | 36,2 + 5,15·x | x = 16 cm: **248** voll / 119 Mehrkosten | ≈ 52 % (16 cm), 48 % (20 cm) |
| Kerndämmung (Einblasen) | 18,7 + 2,98·x | (voll energiebedingt) | x = 6 cm: 37 | 0 % |
| Kellerdecke unterseitig ohne Bekleidung | 55,1 + 2,24·x | voll energiebedingt | x = 10 cm: **78** | 0 % |
| Kellerdecke unterseitig mit Bekleidung | 97,3 + 2,78·x | voll energiebedingt | x = 12 cm: 131 | 0 % (bzw. Bekleidung Ohnehin bei Sanierungsbedarf) |
| Steildach Auf-/Zwischensparren (inkl. Neueindeckung) | 291,8 + 5,35·x | 21,9 + 4,59·x | x = 20 cm: **399** / 114 | ≈ 71 % |
| Steildach nachträgliche Dämmung (ohne Neueindeckung) | 63,3 + 4,49·x | voll energiebedingt | x = 20 cm: 153 | 0 % |
| Flachdach (inkl. Abdichtung, Abbruch) | 199,9 + 7,88·x | 41,6 + 5,58·x | x = 20 cm: **358** / 153 | ≈ 57 % |
| Oberste Geschossdecke begehbar | 52,3 + 3,33·x | voll energiebedingt | x = 20 cm: **119** | 0 % |
| Oberste Geschossdecke nicht begehbar | 6,9 + 1,98·x | voll energiebedingt | x = 24 cm: 55 | 0 % |
| Fenster 2-WSV → 3-WSV (Mehrkosten) MFH | – | 112,9 · F^−0,255 €/m² Fensterfl. (F = m²/Stück) | F = 1,5: **102** | – |
| Fenster 3-WSV → Passivhaus-Fenster MFH (Mehrkosten ggü. 2-WSV) | – | 402,2 · F^−0,136 | F = 1,5: 381 | – |
| Fenster Vollkosten (Kunststoff, 3-WSV, inkl. Ein-/Ausbau) | **850 €/m² Fensterfl.** (600–1.300) | s. o. | | ≈ 85–88 % (Mehrkosten nur ≈ 100–120 €/m²) |
| Haustür MFH / EFH (Vollkosten) | 2.237 / 2.623 €/m² Türfläche | – | | hoch (Ersatz meist ohnehin) |

Fenster-Vollkosten sind in den IWU-Funktionen nicht enthalten → Wert D (Marktpreise 2026, nicht primär belegt). BKI-Richtwert WDVS (EPS bis 200 mm) ca. 180 €/m² netto ohne Abbruch, Gesamtkosten +30–40 % (lt. Schwäbisch Hall, Stand Ende 2025) [C] – konsistent mit 248 €/m² brutto.

### 6.3 Anlagentechnik
**IWU-Kostenfunktionen (Vollkosten 2026, € je m² A_N, A_N in m²) [Q29, B, ×1,12]:**

| Anlage | Funktion (€/m² A_N) | EFH (A_N 180 m²) | MFH (A_N 1.300 m²) | Hinweis |
|---|---|---|---|---|
| Gas-Brennwertkessel (Einzelmaßnahme) | 1.734,7 · A_N^−0,518 | ≈ 21.200 € | ≈ 55.000 € | IWU-Werte eher obere Werte (inkl. Peripherie aus KfW-Vollsanierungen); Markt EFH 2026 ≈ 10–16 T€ (D) |
| Fernwärme-Übergabestation | 1.270,3 · A_N^−0,487 | ≈ 18.200 € | ≈ 50.300 € | zzgl. Hausanschluss FW: 1.024,7 · A_N^−0,614 (EFH ≈ 7.600 €) |
| Pelletkessel | 4.850,9 · A_N^−0,587 | ≈ 41.400 € | ≈ 93.700 € | |
| Ölkessel | 2.304,5 · A_N^−0,536 | ≈ 25.600 € | ≈ 64.200 € | Neueinbau nur noch mit Bio-Treppe |
| Heizungsperipherie (Verteilung, ggf. Sanitär) | 1.277,6 · A_N^−0,533 | ≈ 14.400 € | ≈ 36.400 € | relevant bei WP-Umstellung (Heizflächen) |
| Lüftung zentral mit WRG | 693,9 · A_N^−0,364 | ≈ 18.900 € | ≈ 66.300 € | |
| Lüftung dezentral mit WRG | 1.510,8 · A_N^−0,652 | ≈ 9.200 € | ≈ 18.300 € | |
| Abluftanlage zentral ohne WRG | 1.936,3 · A_N^−0,78 | ≈ 6.100 € | ≈ 9.400 € | |
| Solarthermie (WW) mit neuem Gas-/Ölkessel | 2.095,9 · A_N^−0,489 | ≈ 29.800 € | ≈ 81.800 € | Kombikosten |
| Architekt / Energieberatung | 1.337,8 · A_N^−0,599 / 26,7 · A_N^−0,339 | ≈ 10.700 € / 830 € | ≈ 23.700 € / 3.050 € | Energieberatung voll energiebedingt |

**Wärmepumpen und PV (Marktdaten 2026; IWU-Datenbasis enthält keine WP):**

| Schlüssel | Größe | Default (brutto) | Spanne | Quelle |
|---|---|---|---|---|
| `cost_hp_air_water_efh` | Luft/Wasser-WP EFH inkl. Installation | **32.000 €** | 22.000 / 32.000 / 50.000 | VZ RLP: 160 Angebote 10/2024–05/2025, 20.000–63.000 €, Mittel 36.300 € [Q39, C]; Angebotsauswertung Utopia: Median ≈ 35.000 € [C]; Aroundhome (04/2026) 22.000–35.000 € [C]; 42watt (03/2026) 25.000–30.000 € [C] |
| `cost_hp_brine_water_efh` | Sole/Wasser-WP EFH inkl. Erdsonden | **45.000 €** | 35.000 / 45.000 / 60.000 | 42watt 35.000–50.000 €; ADAC 20.000–49.000 € (lt. cleanthinking) [C] |
| `cost_borehole_per_m` | Erdsondenbohrung je m | 110 €/m | 80–150 | 8.000–15.000 € für ≈ 100 m [C], D |
| `cost_hp_mfh_per_kw` | WP-Anlage MFH (Kaskade, inkl. Hydraulik) je kW_th | **1.800 €/kW** | 1.200 / 1.800 / 2.800 | D (keine belastbare Primärquelle gefunden) |
| `cost_pv_small_per_kwp` | PV ≤ 30 kWp (USt 0 %) | **1.350 €/kWp** | 1.000 / 1.350 / 1.800 | Ø schlüsselfertig Frühjahr 2026 ≈ 1.015 €/kWp (lt. 42watt/elektronik-zeit, Fraunhofer ISE zugeschrieben) [Q40, C]; Anbieter 1.000–1.600 €/kWp [C] |
| `cost_pv_mfh_per_kwp_net` | PV MFH 30–100 kWp, netto | 1.100 €/kWp | 850 / 1.100 / 1.500 | Fraunhofer ISE Modellannahmen Großdach 900–1.600 €/kW netto (2024) [C], D |
| `cost_battery_per_kwh` | Batteriespeicher | 550 €/kWh | 300 / 550 / 800 | 280–500 €/kWh [C], D |
| `cost_inverter_replacement_per_kwp` | Wechselrichtertausch | 150 €/kWp | 100 / 150 / 250 | D |
| `pv_specific_yield` | spez. Ertrag | 950 kWh/(kWp·a) | 800–1.100 | D (Süd/Ost-West abhängig) |

### 6.4 Komplettsanierung auf Effizienzhaus-Niveau (Plausibilitätswerte, Top-down)
Nur als Kreuzprüfung bzw. Schnellmodus – primär Bottom-up nach 6.2/6.3 rechnen.

| Schlüssel | Zielstandard | Default €/m² Wfl. (brutto, inkl. KG 700, ohne Förderung) | Spanne | Ohnehin-Anteil |
|---|---|---|---|---|
| `cost_retrofit_eh85` | EH 85 | 750 | 500 / 750 / 1.100 | 40 % (25–55 %) |
| `cost_retrofit_eh70` | EH 70 | 1.050 | 750 / 1.050 / 1.500 | 40 % (25–55 %) |
| `cost_retrofit_eh55` | EH 55 | 1.350 | 950 / 1.350 / 1.900 | 35 % (20–50 %) |

Quellenlage: Ariadne-Studie (lt. Sekundärquelle) bis 1.450 €/m² Wfl. für EH-55-Niveau ohne Heizung (Preisstand 2025); Ratgeber 2026: EH 70 650–1.500 €/m², MFH 500–1.500 €/m², Tiefsanierung bis 2.200–3.000 €/m² [C]. GdW: CO₂-Vermeidungskosten Effizienzhaus-Sanierung bis 1.034 €/t, Einzelmaßnahmen 132 €/t, Heizungstausch 97 €/t [Q33, B]. → **Qualität D**, hohe Unsicherheit.

### 6.5 Ohnehin-Anteile (Instandsetzungsanteil) – Defaults
| Maßnahme | Default | Spanne | Herleitung |
|---|---|---|---|
| WDVS (wenn Putzsanierung ohnehin fällig) | 0,50 | 0,40–0,65 | IWU Voll- vs. Mehrkosten [Q29] |
| Steildach mit Neueindeckung | 0,70 | 0,60–0,80 | IWU |
| Flachdach mit Abdichtungserneuerung | 0,57 | 0,45–0,65 | IWU |
| Fenstertausch (Ersatz fällig) | 0,85 | 0,75–0,90 | IWU-Mehrkosten ≈ 100–120 €/m² ggü. Vollkosten ≈ 850 €/m² (D) |
| Kellerdecke, oberste Geschossdecke, Kerndämmung | 0,00 | 0–0,1 | keine Ohnehin-Maßnahme |
| Heizungstausch (Referenz Gas-Brennwert) | Kosten Referenzkessel / Kosten neue Anlage | – | Ohnehin = Referenzanlage, Rest energiebedingt |
| Lüftungsanlage | 0,00 | – | |
| Ohnehin-Anteil nur ansetzen, wenn Bauteil am Ende der Nutzungsdauer ist (Restnutzungsdauer ≤ 5 Jahre); sonst anteilig nach Restwert (Vorschlag: linear über Nutzungsdauer). | | | D |

---

## 7. Energiebedarf und Wärmepumpen-Effizienz

### 7.1 Typische Endenergie nach Baualtersklasse (IWU Deutsche Wohngebäudetypologie)
Quelle: IWU (Loga et al. 2015), Anhang C.3, TABULA-Verfahren, Referenzklima Deutschland, **auf typisches Verbrauchsniveau kalibriert**, Bezug beheizte Wohnfläche, Variante Gas-Zentralheizung (älterer NT-Kessel im Ist-Zustand), Endenergie fossil für Heizung + Warmwasser bezogen auf **Hs** [Q30, B]. MP1 = „konventionell“ (Bauteile ≈ EnEV/GEG-Mindestanforderungen, Brennwertkessel), MP2 = „zukunftsweisend“ (Passivhaus-nahe Dämmung, Lüftung mit WRG, Solar).

**EFH** – Heizwärmebedarf q_h / Endenergie fossil (kWh/(m²a)):

| Klasse | Baujahr | Ist q_h | Ist Endenergie | MP1 q_h | MP1 Endenergie | MP2 q_h | MP2 Endenergie |
|---|---|---|---|---|---|---|---|
| EFH_A | … 1859 | 184 | 270 | – | – | – | – |
| EFH_B | 1860–1918 | 181 | 267 | 105 | 144 | 42 | 53 |
| EFH_C | 1919–1948 | 164 | 249 | 92 | 131 | 34 | 44 |
| EFH_D | 1949–1957 | 182 | 268 | 123 | 162 | 47 | 58 |
| EFH_E | 1958–1968 | 180 | 266 | 129 | 168 | 57 | 68 |
| EFH_F | 1969–1978 | 153 | 237 | 99 | 138 | 43 | 54 |
| EFH_G | 1979–1983 | 120 | 200 | 82 | 121 | 28 | 38 |
| EFH_H | 1984–1994 | 132 | 214 | 104 | 143 | 42 | 53 |
| EFH_I | 1995–2001 | 122 | 160 | 107 | 122 | 43 | 54 |
| EFH_J | 2002–2009 | 87 | 125 | 80 | 92 | 40 | 50 |

**MFH** – Heizwärmebedarf q_h / Endenergie fossil (kWh/(m²a)):

| Klasse | Baujahr | Ist q_h | Ist Endenergie | MP1 q_h | MP1 Endenergie | MP2 q_h | MP2 Endenergie |
|---|---|---|---|---|---|---|---|
| MFH_A | … 1859 | 189 | 268 | – | – | – | – |
| MFH_B | 1860–1918 | 145 | 222 | 89 | 125 | 22 | 45 |
| MFH_C | 1919–1948 | 166 | 245 | 91 | 128 | 30 | 54 |
| MFH_D | 1949–1957 | 154 | 232 | 87 | 124 | 30 | 54 |
| MFH_E | 1958–1968 | 127 | 204 | 74 | 111 | 21 | 45 |
| MFH_F | 1969–1978 | 131 | 209 | 81 | 118 | 26 | 50 |
| MFH_G | 1979–1983 | 115 | 192 | 75 | 112 | 23 | 47 |
| MFH_H | 1984–1994 | 119 | 196 | 80 | 117 | 26 | 50 |
| MFH_I | 1995–2001 | 100 | 137 | 76 | 94 | 26 | 43 |
| MFH_J | 2002–2009 | 64 | 100 | 59 | 77 | 23 | 40 |
| GMH_B–F (Großes MFH) | 1860–1978 | – | 191–220 | – | – | – | – |

Unkalibrierte Standardberechnung (Bedarf) liegt z. T. deutlich höher (z. B. EFH_E 448 statt 266 kWh/m²a Endenergie) → **Prebound-Effekt**: tatsächlicher Verbrauch unsanierter Gebäude liegt typ. 30–45 % unter dem rechnerischen Bedarf; nach Sanierung nähern sich Bedarf und Verbrauch an. Konsequenz für die VoFi: Einsparungen auf Basis **Verbrauch vorher** und **kalibriertem Bedarf nachher** rechnen, sonst Überschätzung der Einsparung.

**Wichtig:** Die Typologie-Ist-Zustände sind unmodernisierte Originalzustände. Der reale Bestand ist teilmodernisiert; der bundesweite mittlere Endenergieverbrauch für Raumwärme + WW in Wohngebäuden liegt grob bei 130–150 kWh/(m²a) (dena-Gebäudereport, Wert nicht im Original geprüft, C). → Default im Tool: **gemessener Verbrauch des Objekts** (3-Jahres-Mittel, witterungsbereinigt), Typologie nur als Fallback.

Neubau (Default, D): GModG-/GEG-Mindeststandard ≈ EH 55 mit WP: q_h 35–45 kWh/(m²a), Warmwasser-Nutzwärme 12,5 (EFH) – 16 (MFH) kWh/(m²a), WP-Strom ≈ 15–22 kWh/(m²a); EH 40: q_h 20–30 kWh/(m²a).

### 7.2 Jahresarbeitszahlen (JAZ) Wärmepumpen
| Schlüssel | System | Default | Spanne | Quelle |
|---|---|---|---|---|
| `jaz_air_water_existing` | Luft/Wasser im Bestand (EFH/ZFH) | **3,2** | 2,6 / 3,2 / 4,0 | Fraunhofer ISE „WP-QS im Bestand“: Ø 3,4 (2,6–4,9), 77 Anlagen, Baujahre 1826–2001 [Q38, C]; Default konservativ |
| `jaz_ground_existing` | Sole/Wasser (erdgekoppelt) Bestand | **4,0** | 3,4 / 4,0 / 4,8 | Fraunhofer ISE: Ø 4,3 (3,6–5,4) [Q38, C] |
| `jaz_air_water_newbuild` | Luft/Wasser Neubau | 3,8 | 3,2 / 3,8 / 4,5 | D |
| `jaz_air_water_mfh_central` | Zentral-WP MFH (inkl. WW 60 °C) | 2,9 | 2,4 / 2,9 / 3,5 | D (WW-Anteil, Zirkulation, Hygienetemperatur) |
| `jaz_degradation_per_year` | Alterung | 0,3 %/a | 0–1 %/a | D |

---

## 8. Bewirtschaftungskosten

### 8.1 II. Berechnungsverordnung (Kostenmiete preisgebundener Wohnraum) – gültig ab 01.01.2026
Anpassung alle 3 Jahre nach VPI Okt. 2025 (123,0) ggü. Okt. 2022 (113,5): +8,37 % [Q31, B; bestätigt durch Haus & Grund Düsseldorf/Haufe, C].

| Position | bis 31.12.2025 | **ab 01.01.2026** |
|---|---|---|
| Verwaltungskosten je Wohnung (§ 26 Abs. 2) | 343,69 € | **372,46 €** |
| Verwaltungskosten je Garage/Einstellplatz (§ 26 Abs. 3) | 44,83 € | **48,58 €** |
| Instandhaltung, Bezugsfertigkeit < 22 J. (§ 28 Abs. 2) | 10,61 €/m² | **11,50 €/m²** |
| dto. ≥ 22 J. | 13,45 €/m² | **14,58 €/m²** |
| dto. ≥ 32 J. | 17,18 €/m² | **18,62 €/m²** |
| Abschlag eigenständige gewerbliche Wärmelieferung | −0,29 €/m² | −0,31 €/m² |
| Zuschlag Aufzug | +1,50 €/m² | +1,63 €/m² |
| Abschlag kleine Instandhaltungen durch Mieter (§ 28 Abs. 3) | −1,57 €/m² | −1,70 €/m² |
| Schönheitsreparaturen durch Vermieter (§ 28 Abs. 4) | 12,69 €/m² | 13,75 €/m² (Haufe: 13,76) |
| Garage/Einstellplatz Instandhaltung (§ 28 Abs. 5) | 101,62 € | 110,13 € (Haufe: 110,11) |
| Mietausfallwagnis (§ 29) | 2 % der Erträge | 2 % |

Nächste Anpassung: 01.01.2029 (VPI Okt. 2028 / Okt. 2025). Werte jährlich gemäß Baualter-Stichtag neu zuordnen (Klassenwechsel z. B. Bezugsfertigkeit 2004 → ≥ 22 J. ab 2026).

### 8.2 ImmoWertV Anlage 3 (Modellansätze Ertragswert) – Stand 01.01.2026
Jährliche Fortschreibung mit VPI (Basis 2021) [Q32, B (Oberer Gutachterausschuss Brandenburg, BewKo 2026)]:

| Position | 2022 | 2023 | 2024 | 2025 | **2026** |
|---|---|---|---|---|---|
| Verwaltung je Wohnung bzw. Wohngebäude bei EFH/ZFH | 312 € | 339 € | 351 € | 359 € | **367 €** |
| Verwaltung je Eigentumswohnung | 373 € | 405 € | 421 € | 429 € | **439 €** |
| Verwaltung je Garage/Einstellplatz | 41 € | 44 € | 46 € | 47 € | **48 €** |
| Instandhaltung je m² Wfl. (Mieter trägt Schönheitsrep.) | 12,2 € | 13,2 € | 13,8 € | 14,0 € | **14,4 €** |
| Instandhaltung je Garagenstellplatz | 92 € | 100 € | 104 € | 106 € | **108 €** |
| Mietausfallwagnis Wohnen / Gewerbe | 2 % / 4 % | | | | **2 % / 4 %** |

Keine Differenzierung nach Baualter (ImmoWertV verzichtet bewusst darauf).

### 8.3 Betriebskosten, nicht umlagefähige Kosten
| Größe | Wert | Quelle |
|---|---|---|
| Betriebskosten gesamt (DMB-Betriebskostenspiegel, Abrechnungsjahr 2024) | Ø 2,67 €/m²·Monat (alle denkbaren Arten bis 3,68 €/m²) | [Q42, C] |
| davon Heizung + Warmwasser | Ø 1,32 €/m²·Monat (0,46–2,18) | [Q42, C] |
| GdW-Unternehmen 2024 (Vorauszahlungen) | kalt 1,90 €/m²·Monat (+6,0 %), warm 1,64 €/m²·Monat (+4,7 %) | [Q33, B] |
| Techem-Atlas 2026: Raumwärmekosten MFH 2025 (€/m²·a) | WP 8,80; Pellets 9,36; Öl 12,97; Gas 13,92; Fernwärme 16,02 | [C] |
| `opex_nonrecoverable_share` | nicht umlagefähige Bewirtschaftungskosten (Bankgebühren, Rechts-/Prüfungskosten, nicht umlagefähige Versicherungs-/Wartungsanteile) | Default **1,0 % der Nettokaltmiete** (0,5–2,5 %) – D, keine Primärquelle |
| `opex_vacancy_borne_by_owner` | Betriebskosten leerstehender Einheiten trägt Eigentümer | = Leerstandsquote × Betriebskosten (Modellregel) |
| BelWertV (Beleihungswert) | Mindestabzug Bewirtschaftungskosten 15 % des Rohertrags | [C] |

**Default-Ansatz im Tool:**
- Wohnungsunternehmen (freifinanziert): ImmoWertV-2026-Modellwerte (Verwaltung 367 €/WE, Instandhaltung 14,4 €/m²) als Default, wahlweise unternehmensindividuell (GdW-Unternehmen investierten 2024 rd. 19,7 Mrd. €, 2025 rd. 20,8 Mrd. €, davon 12,7 Mrd. € in den Bestand [Q33, C]; Beispiel VIVAWEST 2025: 49,76 €/m² für Modernisierung und Instandhaltung – unternehmensspezifisch, nicht übertragbar [C]).
- Preisgebundener Wohnraum/Kostenmiete: II. BV 2026.
- Selbstnutzer: keine Verwaltungskosten (optional WEG-Verwalter 300–450 €/WE·a), Instandhaltung 1,0–1,5 % der Herstellungskosten p. a. bzw. ImmoWertV-Satz.
- Instandhaltungspauschale baualtersabhängig erhöhen; nach Vollsanierung Reset auf Neubauniveau (II. BV < 22 J.) – Modellregel D.

---

## 9. Nutzungsdauern von Bauteilen und Anlagen

| Schlüssel | Bauteil/Anlage | Default (Jahre) | Spanne | Quelle / Status |
|---|---|---|---|---|
| `life_hp_air_water` | Luft/Wasser-WP | **18** | 15 / 18 / 22 | VDI 2067-1 (rechnerische Nutzungsdauer) lt. TUM-Studie via Immowelt [Q44, C] |
| `life_hp_brine_water` | Sole/Wasser-, Wasser/Wasser-WP | **20** | 17 / 20 / 25 | VDI 2067-1 lt. [Q44, C] |
| `life_borehole` | Erdwärmesonde | 50 | 40 / 50 / 60 | Fachliteratur (VDI 4640), D |
| `life_gas_boiler` | Gas-Brennwertkessel (wandhängend) | **18** | 15 / 18 / 25 | VDI 2067-1 lt. [Q44, C]; BNB ≈ 20 (nicht geprüft) |
| `life_pellet_boiler` | Pelletkessel | 20 | 15 / 20 / 25 | D |
| `life_district_heating_substation` | FW-Übergabestation | 25 | 20 / 25 / 30 | D |
| `life_etics` | WDVS | **40** | 30 / 40 / 50 | BNB-Tabelle 2017 (Wert aus Fachkenntnis, Original nicht abrufbar) [Q45, D] |
| `life_windows` | Fenster Kunststoff/Holz (Holz-Alu/Alu) | **40** (50) | 30 / 40 / 50 | BNB 2017 [Q45, D] |
| `life_roof_pitched_covering` | Steildacheindeckung (Ziegel/Beton) | 50 | 40 / 50 / 70 | BNB 2017 [Q45, D] |
| `life_roof_flat_sealing` | Flachdachabdichtung (Bitumen/Kunststoff) | 30 | 20 / 30 / 35 | BNB 2017 [Q45, D] |
| `life_insulation_roof_ceiling` | Dämmung Dach/OGD/Kellerdecke | 50 | 40 / 50 / 60 | BNB 2017 [Q45, D] |
| `life_pv_modules` | PV-Module | **25** | 20 / 25 / 30 | Herstellergarantien 25–30 J., BNB 20 (D) |
| `life_pv_inverter` | Wechselrichter | **12** | 10 / 12 / 15 | D |
| `life_battery` | Batteriespeicher | 12 | 10 / 12 / 15 | D |
| `life_ventilation_central` | Lüftungsgerät zentral WRG | 20 | 15 / 20 / 25 | VDI 2067-1 Größenordnung, D |
| `life_ventilation_decentral` | Einzelraumlüfter WRG | 15 | 12 / 15 / 20 | D |
| `life_heating_distribution` | Heizungsverteilung/Heizkörper | 40 | 30 / 40 / 50 | D |
| `life_building_total` | Gesamtnutzungsdauer Wohngebäude (Modell) | **80** | – | ImmoWertV 2021 Anlage 1 (EFH/ZFH/MFH: 80 J.) [Q46, B – aus Fachkenntnis, Text am Stichtag nicht abrufbar (HTTP 503)] |

**Wartung/Instandsetzung als % der Investition p. a.** (VDI-2067-Größenordnung, D – Originaltabelle nicht eingesehen): WP 1,0 % Instandsetzung + 1,5 % Wartung; Gaskessel 1,0 % + 2,0 %; Pelletkessel 2,0 % + 3,0 %; Lüftung 1,5 % + 2,0 % (inkl. Filter); PV 1,0–1,5 % gesamt; Fernwärmestation 1,0 % + 1,0 %. → Vor Freigabe gegen VDI 2067-1:2012 prüfen.

---

## 10. Liegenschaftszinssätze, Kaufpreisfaktoren, Transaktionskosten

### 10.1 Liegenschaftszinssätze (Wohnen)
| Quelle | Objektart / Raum | Wert |
|---|---|---|
| Oberer Gutachterausschuss Brandenburg (beschlossen Apr. 2026; Kauffälle 2023–2025) [Q32, B] | MFH (gewerbl. Anteil ≤ 20 %): Berliner Umland ohne Potsdam / Weiterer Metropolenraum / kreisfreie Städte ohne Potsdam | **3,2 % / 3,5 % / 2,8 %** (Zeitreihe Umland: 2,7 → 2,6 → 2,5 → 2,8 → 3,2 %) |
| dto. Berliner Umland, Stichprobe | Spanne LiZi 0,4–5,6 %; Rohertragsfaktor 13,6–37,6 (Ø 20,7); Ø Nettokaltmiete 8,8 €/m²; RND Ø 45 J. | |
| BewG § 188 Abs. 2 (ErbSt-Bewertung, Auffangwerte) [Q47, C] | Mietwohngrundstücke 3,5 %; gemischt genutzt ≤ 50 % gewerblich 4,5 %, > 50 % 5,0 %; Geschäftsgrundstücke 6,0 % | |
| BewG § 256 (Grundsteuer) [Q47, C] | EFH/ZFH 2,5 %; Wohnungseigentum 3,0 %; Mietwohngrundstücke ≤ 6 WE 4,0 %, > 6 WE 4,5 % | |
| vdp-Index Q4/2025 [Q48, C] | MFH-Liegenschaftszinsen −1,7 % (relativ) ggü. Vorjahr; Kapitalwerte +5,3 % | |

**Defaults (D):** `cap_rate_residential` nach Lage-Preset: A-Metropole 2,5 % (1,5–3,5), Großstadt/Universitätsstadt 3,0 % (2,2–4,0), Mittelstadt 3,5 % (2,5–4,5), ländlich/Schrumpfung 4,5 % (3,5–6,5). Für den Exit-/Restwert im VoFi zusätzlich Zinsaufschlag für Unsicherheit möglich.

### 10.2 Kaufpreisfaktoren (Rohertragsvervielfältiger)
Default `gross_rent_multiplier` = 20 (12 / 20 / 30); Lage-Presets: A 25–32, B 18–25, C 14–20, D/Ost-Schrumpfung 10–15 (D, gestützt auf Brandenburg 20,7 im Berliner Umland [Q32] und Marktberichte).

### 10.3 Grunderwerbsteuer 2026 (Satz auf Kaufpreis) [Q36]
| Land | Satz | Land | Satz |
|---|---|---|---|
| Baden-Württemberg | 5,0 % | Niedersachsen | 5,0 % |
| Bayern | 3,5 % | Nordrhein-Westfalen | 6,5 % |
| Berlin | 6,0 % | Rheinland-Pfalz | 5,0 % |
| Brandenburg | 6,5 % | Saarland | 6,5 % |
| Bremen | **5,5 %** (seit 01.07.2025; Antrag auf Rücknahme zum 01.01.2027, Drs. 21/1941, offen) | Sachsen | 5,5 % |
| Hamburg | 5,5 % | Sachsen-Anhalt | 5,0 % |
| Hessen | 6,0 % | Schleswig-Holstein | 6,5 % |
| Mecklenburg-Vorpommern | 6,0 % | Thüringen | 5,0 % |

Hinweis: Die baufi24-Übersicht (Stand „Oktober 2026“) führt Bremen noch mit 5,0 % – überholt laut Bremer Gesetzblatt Nr. 9 vom 05.02.2025 (Satz 5,5 %) [Q36].

### 10.4 Weitere Transaktionskosten
| Schlüssel | Größe | Default | Spanne | Quelle |
|---|---|---|---|---|
| `cost_notary_land_registry` | Notar + Grundbuch | 1,5 % | 1,1 / 1,5 / 2,0 % | Kaufnebenkostenrechner 2026 (GNotKG-basiert) [Q37, C] |
| `cost_broker_buyer` | Maklerprovision Käufer (EFH/ETW an Verbraucher: Halbteilung) | 3,57 % | 0 / 3,57 / 7,14 % | [Q37, C]; bei MFH/Zinshaus keine Halbteilungspflicht |
| `cost_broker_seller_exit` | Verkaufskosten bei Exit | 3,0 % | 0 / 3,0 / 5,0 % | D |
| `cost_due_diligence` | DD/Gutachten (Unternehmen) | 0,5 % | 0,2–1,0 % | D |

---

## 11. Leerstand

| Quelle | Segment | Wert |
|---|---|---|
| CBRE-empirica-Leerstandsindex (Stand Dez. 2025, Ende 2024) [Q34, C] | marktaktiver Leerstand Geschosswohnungen Deutschland | **2,2 %** (522.000 WE; 2023: 567.000) |
| dto. | West / Ost ohne Berlin | 1,7 % / 5,4 % |
| dto. | Wachstumsregionen / Schrumpfungsregionen | 1,4 % / 6,9 % |
| dto. | Totalleerstand inkl. nicht marktaktiv (fortgeschriebener Zensus) | 963.000 Geschosswohnungen + 727.000 in Eigenheimen |
| Sächsische Wohnungsgenossenschaften / vdw Sachsen, Ende 2025 [Q35, C] | Verbandsunternehmen Ost | 8,2 % / 9,5 % |
| VIVAWEST (NRW), Jahresende 2025 [C] | Großbestandshalter West | 0,8 % |
| GdW (ältere Werte) [C] | neue Länder ohne Berlin (2018) / alte Länder (2015) / GdW gesamt (2015) | 8,3 % / 1,9 % / 4,0 % |

**Lücke:** Aktuelle bundesweite GdW-Leerstandsquoten (Jahresstatistik 2024/2025) waren am Stichtag nicht frei zugänglich (Publikation kostenpflichtig) → beim GdW/Regionalverband anfragen.

**Defaults (D):** `vacancy_rate_structural` Preset: West-Wachstum 1,5 % (0,5–3), Deutschland-Mittel 2,5 %, Ost/ländlich 6 % (3–12), Schrumpfung 9 % (5–15). `vacancy_initial_months_newbuild` (Anlaufleerstand) 3 Monate (0–6). `vacancy_fluctuation_rate` 8 % p. a. (5–12) mit `vacancy_months_per_turnover` 1,0 (0,25–3). `vacancy_during_retrofit_months` 0 (bewohnt) bis 6 (unbewohnt). Mietausfallwagnis (Zahlungsausfall) separat 1–2 %.

---

## 12. Ergänzende regulatorische Parameter (Hinweis, eigene Bibliothek empfohlen)
- **Modernisierungsumlage** § 559 BGB: 8 % p. a., Kappung 3 €/m² (2 €/m² bei Ausgangsmiete < 7 €/m²) in 6 Jahren; vereinfachtes Verfahren § 559c; Heizungs-Umlage § 559e (10 %, Kappung 0,50 €/m²) – Fortgeltung nach GModG und „Mietrecht II“ prüfen [Q53, C].
- **EEG-Einspeisevergütung** ab 01.08.2026 (≤ 10 kWp): Teileinspeisung 7,70 ct/kWh, Volleinspeisung 12,22 ct/kWh (DGS-Arbeitshilfe) [Q41, C]; EEG-Novelle (Kabinett 29.07.2026): feste Vergütung für Neuanlagen soll ab 2027 entfallen, Übergangszahlung (Angaben widersprüchlich: 5,2 ct/kWh für 36 Monate bzw. ≈ 1 ct unter regulär) [Q41, C] → Parameter mit `valid_to: 2026-12-31`.
- **BEG/KfW 458 (ab 21.07.2026):** Grundförderung 30 %, Klimageschwindigkeitsbonus 20 % (bis Ende 2028), Einkommensbonus 30 %, Effizienzbonus 5 %, Höchstsatz 70 %; förderfähige Kosten lt. Sekundärquelle 28.000 € für die erste WE [Q52, C] – in Förder-Bibliothek, vor Nutzung verifizieren.
- **GModG Bio-Treppe** für neu eingebaute Gas-/Öl-/LPG-Kessel im Bestand: 10 % (2029), 15 % (2030), 30 % (2035), 60 % (2040) biogene/klimaneutrale Brennstoffe [Q19c, B]; 65-%-EE-Pflicht (§§ 71–71p GEG) und Betriebsverbot fossiler Kessel (§ 72 Abs. 4) entfallen [Q19c].

---

## 13. Empfehlungen für YAML-Struktur und MC-Implementierung

1. **Schema je Parameter:** `label_de`, `unit`, `value`, `dist` (`type`, Parameter), `as_of`, `valid_from`, `valid_to`, `sources` (IDs), `quality` (A–D), `volatility` (niedrig/mittel/hoch/sehr hoch), `price_basis` (brutto/netto, Hs/Hi), `note_de`. Zeitreihen über `path` (Jahr → Wert), Szenarien über `scenarios`.
2. **Getrennte Dateien** in `inst/extdata/params/`: `energy_prices.yaml`, `co2.yaml`, `rates.yaml`, `macro.yaml`, `costs_newbuild.yaml`, `costs_retrofit.yaml`, `demand.yaml`, `operating_costs.yaml`, `lifetimes.yaml`, `valuation_transaction.yaml`, `vacancy.yaml`, `sources.yaml`. Das konsolidierte YAML unten ist so gegliedert, dass es 1:1 in diese Dateien aufgeteilt werden kann.
3. **Versionierung:** `meta.version` = `JJJJ.MM.n`; jede Änderung mit Datum, Bearbeiter, Quelle. Update-Rhythmus: Energiepreise/Zinsen quartalsweise; CO₂/Recht bei Gesetzesänderung; II. BV 2029; ImmoWertV jährlich (Januar); Baukosten halbjährlich.
4. **Validierung beim Laden:** min ≤ mode ≤ max; Einheiten-Whitelist; Ablaufwarnung, wenn `as_of` älter als 12 Monate oder `valid_to` überschritten (z. B. GEG-Anlage-9-Faktoren ab 2027).
5. **MC:** Startwert-Unsicherheit (`dist`) und Pfaddynamik (`dynamics`) getrennt; gemeinsame Innovationen über Cholesky der geschrumpften Korrelationsmatrix; CO₂ komonoton über Stützjahre; Zinsen Vasicek; Seed und Zahl der Läufe (Default 10.000) dokumentieren.
6. **Keine volatilen Werte im R-Code**; R-Code liest ausschließlich YAML (und ggf. nutzerdefinierte Overrides).

---

## 14. Offene Fragen an den Nutzer
1. **Startpreis-Logik:** Soll der Default für Energiepreise das 12-Monats-Mittel (Empfehlung) oder der aktuelle Spotpreis sein? Soll das Tool Krisenabweichungen automatisch abbauen (Mean-Reversion)?
2. **Regionale Presets:** Sollen Lage-Presets (A/B/C/D, Ost/West, Wachstum/Schrumpfung) für Mieten, Leerstand, Liegenschaftszins, Kaufpreisfaktor, Grunderwerbsteuer (Bundesland) eingeführt werden?
3. **Umsatzsteuer:** Bestätigung, dass Wohnungsunternehmen standardmäßig brutto rechnen; Sonderfälle (gewerbliche Einheiten, Mieterstrom-Tochter, Contracting) als Option?
4. **Hs/Hi-Konvention:** Erdgas im Tool durchgängig auf Brennwert (Abrechnung) – einverstanden?
5. **Kostenmiete/geförderter Wohnungsbau:** Wird die II. BV-Logik (Kostenmiete, Bindungen) in v1 benötigt oder nur als Bewirtschaftungskosten-Option?
6. **CO₂-Kostenaufteilung:** Soll die erwartete GModG-Regel (50/50 ab 2028) bereits als Default aktiv sein, obwohl der Gesetzestext noch nicht geprüft ist?
7. **Förder-Bibliothek:** Separate Recherche zu BEG/KfW/Landesförderung (Zuschüsse, Tilgungszuschüsse, Kumulierung) gewünscht? (In diesem Memo nur Zinsen.)
8. **Real- vs. Nominalrechnung:** VoFi nominal mit VPI-Pfad (Empfehlung) oder real?
9. **Unternehmensindividuelle Kennzahlen:** Gibt es interne Benchmarks (Instandhaltung €/m², Leerstand, Fluktuation, Finanzierungskonditionen), die als Overrides hinterlegt werden sollen?
10. **Zeitraster:** Jahresschritte ausreichend, oder Monatsschritte für Bau-/Zwischenfinanzierungsphase?

## 15. Risiken
- **Krisenverzerrung 2026:** Energie- und Zinsniveaus sind durch den Nahost-Konflikt außergewöhnlich; deterministische Defaults können in wenigen Monaten veraltet sein (insbesondere Heizöl, Gas 2027).
- **CO₂-Pfad:** Größte Einzelunsicherheit für fossile Varianten (Spanne 2035: 75–200 €/t); politische Eingriffe (Korridor 2027, ETS2-MSR-Reform, mögliche weitere Verschiebung) sind wahrscheinlich.
- **Rechtsunsicherheit GModG:** Neue Anlage-9-Faktoren, Primärenergiefaktoren und CO₂-Kostenaufteilung ab 2027/2028 nicht im amtlichen Text verifiziert; DUH-Klage angekündigt.
- **Sekundärquellen:** Mehrere Werte (Destatis H1 2026, Heizöl-Portalpreise, DEPI, Verivox, Dr. Klein, EZB/Bundesbank-Prognosen, CBRE-empirica, WP-/PV-Kosten, VDI-2067-Nutzungsdauern, BNB-Werte, BewG-Sätze) stammen aus Websuche/Sekundärberichten (Qualität C/D) und sollten vor Freigabe im Original geprüft werden.
- **Kostenfunktionen:** IWU-Funktionen basieren auf Abrechnungen bis 2015 (KfW-geförderte Vollsanierungen) und werden nur indexiert; Produktivitäts- und Marktveränderungen (z. B. WP-Preise, Fachkräftemangel) sind nicht abgebildet. Wärmepumpenkosten streuen um Faktor 2–3.
- **Korrelations- und Zinsmodell:** Schätzungen beruhen auf kurzen Reihen (25 Jahresbeobachtungen) bzw. einer Phase säkular fallender Zinsen; Gleichgewichtszins und Spreads sind normativ gesetzt.
- **Energiebedarf:** Typologie-Werte bilden unmodernisierte Gebäude ab; ohne Verbrauchsdaten drohen überschätzte Einsparungen (Prebound-Effekt) und Rebound nach Sanierung.
- **Leerstand/Liegenschaftszins:** Stark regional; bundesweite GdW-Werte fehlen; Default-Presets sind Expertenschätzungen.

---

## 16. Quellenverzeichnis (abgerufen am 25.10.2026, sofern nicht anders angegeben)

| ID | Quelle | URL | Datenstand |
|---|---|---|---|
| Q01 | BDEW-Strompreisanalyse Haushalte und Industrie, August 2026 | https://www.bdew.de/media/documents/BDEW_Strompreisanalyse_082026.pdf | 08/2026 |
| Q02 | BDEW-Gaspreisanalyse Haushalte und Industrie, August 2026 | https://www.bdew.de/media/documents/BDEW_Gaspreisanalyse_082026.pdf | 08/2026 |
| Q03 | Destatis, PM „Strom- und Gaspreise für Haushalte im 1. Halbjahr 2026 gesunken“ (30.09.2026; über Websuche, nicht im Original geprüft) | https://www.destatis.de/DE/Presse/Pressemitteilungen/2026/09/PD26_345_61243.html | 1. Hj 2026 |
| Q04 | Destatis, PM Nr. 364 vom 13.10.2026 (VPI September 2026) | https://www.destatis.de/DE/Presse/Pressemitteilungen/2026/10/PD26_364_611.html | 09/2026 |
| Q05 | Bundesnetzagentur/Bundeskartellamt, Monitoringbericht 2025 (Tab. 38, 39, 45, 68) | https://data.bundesnetzagentur.de/Bundesnetzagentur/SharedDocs/Mediathek/Monitoringberichte/MonitoringberichtEnergie2025.pdf | 01.04.2025 |
| Q06 | cleanthinking.de, „Was Heizen im Winter 2026/27 wirklich kostet“ (Sept. 2026; zitiert BDEW, Destatis, waermepreise.info, DEHSt) | https://www.cleanthinking.de/?p=1073584 | 08–09/2026 |
| Q07 | ZfK, „Fernwärmepreise 2026: Klarer Trend erkennbar“ (06.03.2026) | https://www.zfk.de/energie/waermewende/fernwaermepreise-2026-klarer-trend-erkennbar | 01/2026 |
| Q08 | Heizölpreisportale (Heizöl24, esyoil; EU Oil Bulletin über benzinampel.de) – über Websuche | https://www.heizoel24.de/heizoelpreise ; https://www.esyoil.com/ ; https://benzinampel.de/heizoelpreise | 19.–25.10.2026 |
| Q09 | DEPI-Pelletpreis Oktober 2026 (über topagrar/haustechnikdialog) | https://www.topagrar.com/energie/news/pelletspreis-steigt-im-oktober-2026-weniger-stark-an-20030280.html | 10/2026 |
| Q10 | DEPI-Jahresdurchschnitt 2025 (343,01 €/t) und Monatswerte (über haustechnikdialog/aroundhome, Websuche) | https://www.haustechnikdialog.de/News/31026/Pelletpreis-weiter-auf-Winterniveau | 12/2025 |
| Q11 | Verivox-Daten über stromauskunft.de (14.09.2026); 42watt Gaspreisentwicklung (02.10.2026) | https://www.stromauskunft.de/gas/gaspreise-deutschland/ ; https://42watt.de/magazin/gaspreisentwicklung | 09–10/2026 |
| Q12 | Eurostat, HVPI Jahresdurchschnitte `prc_hicp_aind` (DE) | https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/prc_hicp_aind | 06.02.2026 |
| Q13 | Eurostat, Baupreise neue Wohngebäude `sts_copi_a` (DE, 2021=100) | https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/sts_copi_a | 26.09.2026 |
| Q14 | UBA/Prognos, Rahmendaten und Endverbrauchspreise für die THG-Projektionen 2026 (Apr. 2026), Tab. 5, 7, 8 | https://www.umweltbundesamt.de/system/files/medien/11850/publikationen/2026-04/2026_Rahmendatenpapier.pdf | 12/2025 |
| Q15 | UBA Climate Change 15/2026, „EU ETS 2 Market Stability Reserve: Analysis of Reform Proposals“ (Veyt/TCD) | https://www.umweltbundesamt.de/system/files/medien/11850/publikationen/2026-03/15_2026_CC.pdf | 10/2025 |
| Q16 | ZDH Europa aktuell, ETS2-MSR-Einigung (19.06.2026); Ratsbeschluss 09.10.2026 lt. Websuche | https://www.zdh.de/ueber-uns/fachbereich-europapolitik/europa-aktuell/default-fc16eb929b6b5aade0d6b1b0957e427b/ | 06–10/2026 |
| Q17 | Carbon Pulse, Analystenprognosen ETS2 (Okt. 2026; Apr. 2026) – Paywall, nur Teaser | https://carbon-pulse.com/557713/ | 04–10/2026 |
| Q18 | Drittes BEHG-Änderungsgesetz: BR-Drs. 462/26; IHK Nürnberg; EY | https://dserver.bundestag.de/brd/2026/0462-26.pdf ; https://www.ihk-nuernberg.de/meldungen/details/behg-kabinett-beschliesst-brennstoffemissionshandelsgesetz | 08–09/2026 |
| Q19 | GModG Anlage 9 (buzer.de, Fassung m. W. v. 01.01.2023; Neufassung durch G. v. 23.07.2026) | https://www.buzer.de/Anlage_9_GModG.htm | 10/2026 |
| Q19b | nexvyra.de, GModG § 22 / Anlage 4 (Sekundärquelle, Werte 2027 als offen gekennzeichnet) | https://nexvyra.de/fakten/gmodg-22-anlage-4-primaerenergiefaktoren | 2026 |
| Q19c | GÖRG, „Gebäudemodernisierungsgesetz (GModG) schafft GEG ab“ (17.07.2026) | https://www.goerg.de/de/aktuelles/veroeffentlichungen/17-07-2026/gebaeudemodernisierungsgesetz-gmodg-schafft-geg-ab-was-sich-aendert-und-was-bleibt | 07/2026 |
| Q20 | EBeV 2030, Anlage 2 (Standardwerte) | https://gesetze.legal/bund/ebev_2030/anlage_2 | geltende Fassung |
| Q21 | CO2KostAufG-Stufenmodell (EAM-FAQ 01/2024, Websuche) | https://www.eam.de/fileadmin/user_upload/bilder/service/FAQ_EAMP_CO2KostAufG_01_2024_.pdf | 01/2024 |
| Q22 | Deutsche Bundesbank, Zeitreihen-API: BBIM1 (SUD101–SUD189), BBSIS (Svensson 1/5/10/20 J.), BBIN1 (EZB), BBDP1 (VPI) | https://api.statistiken.bundesbank.de/rest/data/ | 08–10/2026 |
| Q23 | KfW-Konditionenanzeiger | https://www.kfw-formularsammlung.de/KonditionenanzeigerINet/KonditionenAnzeiger | 22.10.2026 |
| Q24 | Dr. Klein, Bauzinsen aktuell (Websuche) | https://www.drklein.de/finanzlexikon/darlehenszinsen.html | 13.10.2026 |
| Q25 | Bundesbank-Projektion Juni 2026 (über mehrwertsteuerrechner.de); EZB-Stab-Projektionen Sept. 2026 (über lovguiden.dk / investinglive) | https://www.mehrwertsteuerrechner.de/inflation/inflation-deutschland/prognose/ ; https://www.ecb.europa.eu/press/projections/html/index.en.html | 06–09/2026 |
| Q26 | DIW, Gemeinschaftsdiagnose Frühjahr 2026 | https://www.diw.de/de/diw_01.c.1004058.de/gemeinschaftsdiagnose_fruehjahr_2026__energiepreisschock_daempft_erholung_____inflation_steigt.html | 04/2026 |
| Q27 | baulinks.de, „Baupreise im Wohnungsbau und Straßenbau erneut gestiegen“ (09.10.2026, Destatis); Destatis PM 241 (10.07.2026) | https://www.baulinks.de/webplugin/2026/1503.php4 ; https://www.destatis.de/DE/Presse/Pressemitteilungen/2026/07/PD26_241_61261.html | 08/2026 |
| Q28 | ARGE e. V. (Walberg u. a.), „Wohnungsbau in Deutschland 2026“ (März 2026) | https://mieterbund.de/app/uploads/2026/03/studie_zum_wohnungsbau_2026.pdf | Q4/2025 |
| Q28b | ARGE e. V., Charts Wohnungsbau-Tag 2025 (Websuche) | https://www.impulse-fuer-den-wohnungsbau.de/fileadmin/images/Wohnungsbautag/2025/pressemappe/Charts_zur_Studie_-_Bauplan_D_2030.pdf | 2025 |
| Q29 | IWU (Müller, Fiedler, Koch), Working Paper Anpassung der Kostenfunktionen 2022/2023 (08.08.2024) | https://iwu.de/fileadmin/publikationen/energie/2024_IWU_MuellerEtAl_WorkingPaper-Anpassung-Kostenfunktionen-2022-2023.pdf | 2023 |
| Q30 | IWU (Loga et al.), Deutsche Wohngebäudetypologie, 2. Aufl. 2015, Anhang C.3 | https://www.iwu.de/fileadmin/publikationen/gebaeudebestand/episcope/2015_IWU_LogaEtAl_Deutsche-Wohngeb%C3%A4udetypologie.pdf | 2015 |
| Q31 | VdW Bayern, II. BV: Anpassung der Pauschalen zum 01.01.2026 (Nov. 2025) | https://www.vdwbayern.de/wp-content/uploads/2025/11/VdW_Zweite-Berechnungsverordnung_Pauschalen_2026_fin.pdf | 01.01.2026 |
| Q32 | Oberer Gutachterausschuss Brandenburg: Bewirtschaftungskosten 2022–2026; Liegenschaftszinssätze 2025 (Apr. 2026) | https://gutachterausschuss.brandenburg.de/sixcms/media.php/9/BewKo_2026.pdf ; https://gutachterausschuss.brandenburg.de/sixcms/media.php/9/LIZI_2025_OGA.pdf | 2026 |
| Q33 | GdW, PM Jahrespressekonferenz 23.06.2025; Wohnungswirtschaftliche Daten und Trends 2025/2026 (Kurzfassung) | https://www.gdw.de/media/2025/06/pressemitteilung_gdw-jahrespressekonferenz-2025.pdf ; https://wohnungswirtschaft-heute.de/wp-content/uploads/2026/01/gdw_25_daten-trends_a4_inhalt.pdf | 2024/2025 |
| Q34 | CBRE-empirica-Leerstandsindex (über cash-online, Websuche) | https://www.cash-online.de/a/wohnungsleerstand-sinkt-deutlich-auf-522-000-einheiten-708662/ | Ende 2024 |
| Q35 | Sachsen Fernsehen, Leerstand sächsischer Wohnungsunternehmen (29.05.2026) | https://www.sachsen-fernsehen.de/amp/bezahlbares-wohnen-in-sachsen-unter-druck-2236254/ | Ende 2025 |
| Q36 | baufi24 Grunderwerbsteuer-Übersicht; Bremisches Gesetzblatt Nr. 9 (05.02.2025); Bürgerschafts-Drs. 21/1941 (19.08.2026) | https://www.baufi24.de/grunderwerbsteuer/ ; https://www.gesetzblatt.bremen.de/fastmedia/218/2025_02_05_GBl_Nr_0009_signed.pdf ; https://www.bremische-buergerschaft.de/drs_abo/2026-08-19_Drs-21-1941_1c1d4.pdf | 2026 |
| Q37 | baufivergleich.de, Kaufnebenkostenrechner 2026 (Websuche) | https://baufivergleich.de/kaufnebenkosten-rechner/ | 2026 |
| Q38 | Fraunhofer ISE „WP-QS im Bestand“ (über 42watt/ingenieur.de) | https://42watt.de/magazin/jahresarbeitszahl | 2024/2025 |
| Q39 | Wärmepumpenkosten: VZ RLP-Angebotsauswertung, Aroundhome, 42watt, Enpal, Verivox-WP-Tarif (Websuche) | https://www.aroundhome.de/heizung/waermepumpe/preise-kosten ; https://42watt.de/magazin/was-kostet-eine-warmepumpe-mit-einbau | 2025/2026 |
| Q40 | PV-Kosten 2026 (42watt; elektronik-zeit; reduco) | https://42watt.de/magazin/photovoltaik-kosten | 03–05/2026 |
| Q41 | DGS-Arbeitshilfe EEG-Vergütungssätze 01.08.2026; t-online/Börse Express zur EEG-Novelle | https://www.dgs.de/wp-content/uploads/2026/08/260801_dgs_arbeitshilfe_eeg_verguetungssaetze.pdf ; https://www.t-online.de/finanzen/energie/id_101358120/eeg-und-netzpaket-einspeiseverguetung-wird-abgeschafft.html | 08/2026 |
| Q42 | Deutscher Mieterbund, Betriebskostenspiegel (Abrechnungsjahr 2024) | https://mieterbund.de/aktuelles/meldungen/mieterbund-veroeffentlicht-aktuellen-betriebskostenspiegel-fuer-deutschland/ | 2024 |
| Q43 | ImmoScout24 WohnBarometer Q2/2026 Miete; IfW GREIX Mietpreisindex | https://www.immobilienscout24.de/unternehmen/fileadmin/user_upload/WohnBarometer_Q2_2026_Miete.pdf ; https://www.ifw-kiel.de/ | Q2/2026; Q4/2025 |
| Q44 | Immowelt, Lebensdauer von Wärmepumpen (zitiert TUM-Studie / VDI 2067) | https://www.immowelt.de/ratgeber/news/lebensdauer-von-waermepumpen-so-lange-halten-sie-im-vergleich-zu-oel-und-gasheizung | 2025/2026 |
| Q45 | BBSR/BNB, Nutzungsdauern von Bauteilen (2017; Original am Stichtag nicht abrufbar) | https://www.nachhaltigesbauen.de/ | 2017 |
| Q46 | ImmoWertV 2021, Anlage 1 (Gesamtnutzungsdauer) und Anlage 3 | https://www.gesetze-im-internet.de/immowertv_2022/ | geltende Fassung |
| Q47 | BewG § 188, § 256 | https://www.gesetze-im-internet.de/bewg/__188.html ; https://www.gesetze-im-internet.de/bewg/__256.html | geltende Fassung |
| Q48 | vdp-Immobilienpreisindex, Indexveränderungen Q4/2025 | https://www.pfandbrief.de/wp-content/uploads/2026/02/Index-Veraenderungen_DE_Q4_2025.pdf | Q4/2025 |
| Q49 | Destatis, Baugenehmigungen im Hochbau (Tabelle, Stand 18.02.2026); Schwäbisch Hall (Baukosten je m² 2024) | https://www.destatis.de/DE/Themen/Branchen-Unternehmen/Bauen/Tabellen/baugenehmigungen.html | 2025 |
| Q51 | OIES Quarterly Gas Market Review / Goldman Sachs TTF-Prognosen (über trend.az, oilandgas360; Websuche) | https://www.trend.az/world/4235829.html | 07–10/2026 |
| Q52 | KfW 458 Konditionen ab 21.07.2026 (greenox, DUH-Factsheet; Websuche) | https://greenox-group.de/warmepumpe/ | 07/2026 |
| Q53 | Mietrecht (Modernisierungsumlage, Mietpreisbremse bis 2029, Reform „Mietrecht II“) – Websuche (vdiv, LTO) | https://vdiv.de/news-details/mietrechtsreform-2026-deckel-fuer-indexmieten-und-neue-spielregeln-fuer-vermieter | 2026 |

---

## 17. Konsolidiertes YAML (Vorlage für `inst/extdata/params/*.yaml`)

```yaml
# ---------------------------------------------------------------------------
# VoFi – Default-Parameterbibliothek
# Stand: 2026-10-25 · Sprache Labels/Hinweise: de · Schlüssel: en (snake_case)
# Qualitätsstufen: A amtlich/primär geprüft, B Verband/Institut geprüft,
#                  C Sekundärquelle/Websuche, D eigene Ableitung/Expertenschätzung
# Verteilungen: triangular(min, mode, max), normal(mean, sd), lognormal(meanlog, sdlog)
# ---------------------------------------------------------------------------
meta:
  library: "vofi_default_parameters"
  version: "2026.10.0"
  as_of: "2026-10-25"
  currency: "EUR"
  price_level: "nominal"
  base_year: 2026
  author_note_de: "Erstfassung aus Recherche-Memo docs/recherche/03_parameter_defaults.md"
  vat_rule_de: "Privatpersonen und Wohnungsunternehmen (Wohnraum, § 4 Nr. 12 UStG ohne Vorsteuerabzug) rechnen brutto; *_net nur für gewerbliche Fälle."

sources:
  Q01: {publisher: "BDEW", title: "Strompreisanalyse August 2026", url: "https://www.bdew.de/media/documents/BDEW_Strompreisanalyse_082026.pdf", date: "2026-08"}
  Q02: {publisher: "BDEW", title: "Gaspreisanalyse August 2026", url: "https://www.bdew.de/media/documents/BDEW_Gaspreisanalyse_082026.pdf", date: "2026-08"}
  Q03: {publisher: "Destatis", title: "PM Strom- und Gaspreise 1. Hj 2026 (über Websuche)", url: "https://www.destatis.de/DE/Presse/Pressemitteilungen/2026/09/PD26_345_61243.html", date: "2026-09-30"}
  Q04: {publisher: "Destatis", title: "PM 364 VPI September 2026", url: "https://www.destatis.de/DE/Presse/Pressemitteilungen/2026/10/PD26_364_611.html", date: "2026-10-13"}
  Q05: {publisher: "BNetzA/BKartA", title: "Monitoringbericht 2025", url: "https://data.bundesnetzagentur.de/Bundesnetzagentur/SharedDocs/Mediathek/Monitoringberichte/MonitoringberichtEnergie2025.pdf", date: "2025-04-01"}
  Q06: {publisher: "cleanthinking.de", title: "Was Heizen im Winter 2026/27 wirklich kostet", url: "https://www.cleanthinking.de/?p=1073584", date: "2026-09"}
  Q07: {publisher: "ZfK", title: "Fernwärmepreise 2026", url: "https://www.zfk.de/energie/waermewende/fernwaermepreise-2026-klarer-trend-erkennbar", date: "2026-03-06"}
  Q08: {publisher: "Heizöl24/esyoil/EU Oil Bulletin", title: "Heizölpreise Oktober 2026 (Websuche)", url: "https://www.heizoel24.de/heizoelpreise", date: "2026-10-25"}
  Q09: {publisher: "DEPI über topagrar", title: "Pelletpreis Oktober 2026", url: "https://www.topagrar.com/energie/news/pelletspreis-steigt-im-oktober-2026-weniger-stark-an-20030280.html", date: "2026-10"}
  Q10: {publisher: "DEPI über haustechnikdialog", title: "Pelletpreise 2025 (Jahresmittel 343,01 EUR/t)", url: "https://www.haustechnikdialog.de/News/31026/Pelletpreis-weiter-auf-Winterniveau", date: "2025-12"}
  Q11: {publisher: "Verivox über stromauskunft.de; 42watt", title: "Gaspreise Neukunden 2026", url: "https://www.stromauskunft.de/gas/gaspreise-deutschland/", date: "2026-09-14"}
  Q12: {publisher: "Eurostat", title: "HICP annual data prc_hicp_aind (DE)", url: "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/prc_hicp_aind", date: "2026-02-06"}
  Q13: {publisher: "Eurostat", title: "Construction producer prices new residential buildings sts_copi_a (DE)", url: "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/sts_copi_a", date: "2026-09-26"}
  Q14: {publisher: "UBA/Prognos", title: "Rahmendaten THG-Projektionen 2026", url: "https://www.umweltbundesamt.de/system/files/medien/11850/publikationen/2026-04/2026_Rahmendatenpapier.pdf", date: "2026-04"}
  Q15: {publisher: "UBA (Veyt/TCD)", title: "Climate Change 15/2026 EU ETS 2 MSR", url: "https://www.umweltbundesamt.de/system/files/medien/11850/publikationen/2026-03/15_2026_CC.pdf", date: "2026-03"}
  Q16: {publisher: "ZDH", title: "ETS2-MSR-Einigung Rat/EP", url: "https://www.zdh.de/ueber-uns/fachbereich-europapolitik/europa-aktuell/default-fc16eb929b6b5aade0d6b1b0957e427b/", date: "2026-06-19"}
  Q17: {publisher: "Carbon Pulse", title: "ETS2-Analystenprognosen (Teaser)", url: "https://carbon-pulse.com/557713/", date: "2026-10"}
  Q18: {publisher: "Bundesrat/IHK Nürnberg", title: "Drittes BEHG-Änderungsgesetz (BR-Drs. 462/26)", url: "https://dserver.bundestag.de/brd/2026/0462-26.pdf", date: "2026-08-12"}
  Q19: {publisher: "buzer.de", title: "GModG Anlage 9", url: "https://www.buzer.de/Anlage_9_GModG.htm", date: "2026-10"}
  Q19b: {publisher: "nexvyra.de", title: "GModG Primärenergiefaktoren 2027 (unverifiziert)", url: "https://nexvyra.de/fakten/gmodg-22-anlage-4-primaerenergiefaktoren", date: "2026"}
  Q19c: {publisher: "GÖRG", title: "GModG schafft GEG ab", url: "https://www.goerg.de/de/aktuelles/veroeffentlichungen/17-07-2026/gebaeudemodernisierungsgesetz-gmodg-schafft-geg-ab-was-sich-aendert-und-was-bleibt", date: "2026-07-17"}
  Q20: {publisher: "BMJ/gesetze.legal", title: "EBeV 2030 Anlage 2", url: "https://gesetze.legal/bund/ebev_2030/anlage_2", date: "geltend"}
  Q21: {publisher: "EAM", title: "FAQ CO2KostAufG", url: "https://www.eam.de/fileadmin/user_upload/bilder/service/FAQ_EAMP_CO2KostAufG_01_2024_.pdf", date: "2024-01"}
  Q22: {publisher: "Deutsche Bundesbank", title: "Zeitreihen-API BBIM1/BBSIS/BBIN1/BBDP1", url: "https://api.statistiken.bundesbank.de/rest/data/", date: "2026-10-25"}
  Q23: {publisher: "KfW", title: "Konditionenanzeiger", url: "https://www.kfw-formularsammlung.de/KonditionenanzeigerINet/KonditionenAnzeiger", date: "2026-10-22"}
  Q24: {publisher: "Dr. Klein", title: "Bauzinsen aktuell (Websuche)", url: "https://www.drklein.de/finanzlexikon/darlehenszinsen.html", date: "2026-10-13"}
  Q25: {publisher: "Bundesbank/EZB (über Sekundärquellen)", title: "Inflationsprojektionen Juni/Sept. 2026", url: "https://www.ecb.europa.eu/press/projections/html/index.en.html", date: "2026-09"}
  Q26: {publisher: "DIW/Gemeinschaftsdiagnose", title: "Frühjahr 2026", url: "https://www.diw.de/de/diw_01.c.1004058.de/gemeinschaftsdiagnose_fruehjahr_2026__energiepreisschock_daempft_erholung_____inflation_steigt.html", date: "2026-04"}
  Q27: {publisher: "baulinks.de (Destatis)", title: "Baupreise August 2026", url: "https://www.baulinks.de/webplugin/2026/1503.php4", date: "2026-10-09"}
  Q28: {publisher: "ARGE e.V.", title: "Wohnungsbau in Deutschland 2026", url: "https://mieterbund.de/app/uploads/2026/03/studie_zum_wohnungsbau_2026.pdf", date: "2026-03"}
  Q29: {publisher: "IWU", title: "Kostenfunktionen 2022/2023 (Working Paper)", url: "https://iwu.de/fileadmin/publikationen/energie/2024_IWU_MuellerEtAl_WorkingPaper-Anpassung-Kostenfunktionen-2022-2023.pdf", date: "2024-08-08"}
  Q30: {publisher: "IWU", title: "Deutsche Wohngebäudetypologie 2015", url: "https://www.iwu.de/fileadmin/publikationen/gebaeudebestand/episcope/2015_IWU_LogaEtAl_Deutsche-Wohngeb%C3%A4udetypologie.pdf", date: "2015"}
  Q31: {publisher: "VdW Bayern", title: "II. BV Pauschalen ab 01.01.2026", url: "https://www.vdwbayern.de/wp-content/uploads/2025/11/VdW_Zweite-Berechnungsverordnung_Pauschalen_2026_fin.pdf", date: "2025-11"}
  Q32: {publisher: "Oberer Gutachterausschuss Brandenburg", title: "BewKo 2026; Liegenschaftszinssätze 2025", url: "https://gutachterausschuss.brandenburg.de/sixcms/media.php/9/BewKo_2026.pdf", date: "2026-04"}
  Q33: {publisher: "GdW", title: "Jahrespressekonferenz 2025; Daten und Trends 2025/2026", url: "https://www.gdw.de/media/2025/06/pressemitteilung_gdw-jahrespressekonferenz-2025.pdf", date: "2025-06-23"}
  Q34: {publisher: "CBRE/empirica über cash-online", title: "Leerstandsindex (Ende 2024)", url: "https://www.cash-online.de/a/wohnungsleerstand-sinkt-deutlich-auf-522-000-einheiten-708662/", date: "2025-12"}
  Q35: {publisher: "Sachsen Fernsehen (vdw/VSWG)", title: "Leerstand Sachsen 2025", url: "https://www.sachsen-fernsehen.de/amp/bezahlbares-wohnen-in-sachsen-unter-druck-2236254/", date: "2026-05-29"}
  Q36: {publisher: "baufi24; Bremisches Gesetzblatt", title: "Grunderwerbsteuersätze 2026", url: "https://www.baufi24.de/grunderwerbsteuer/", date: "2026"}
  Q37: {publisher: "baufivergleich.de", title: "Kaufnebenkostenrechner 2026", url: "https://baufivergleich.de/kaufnebenkosten-rechner/", date: "2026"}
  Q38: {publisher: "Fraunhofer ISE über 42watt", title: "WP-QS im Bestand (JAZ)", url: "https://42watt.de/magazin/jahresarbeitszahl", date: "2025"}
  Q39: {publisher: "VZ RLP/Aroundhome/42watt (Websuche)", title: "Wärmepumpenkosten 2025/2026", url: "https://www.aroundhome.de/heizung/waermepumpe/preise-kosten", date: "2026-04"}
  Q40: {publisher: "42watt (Fraunhofer ISE)", title: "Photovoltaik-Kosten 2026", url: "https://42watt.de/magazin/photovoltaik-kosten", date: "2026-03"}
  Q41: {publisher: "DGS; t-online", title: "EEG-Vergütungssätze ab 01.08.2026; EEG-Novelle", url: "https://www.dgs.de/wp-content/uploads/2026/08/260801_dgs_arbeitshilfe_eeg_verguetungssaetze.pdf", date: "2026-08-01"}
  Q42: {publisher: "Deutscher Mieterbund", title: "Betriebskostenspiegel (Abrechnungsjahr 2024)", url: "https://mieterbund.de/aktuelles/meldungen/mieterbund-veroeffentlicht-aktuellen-betriebskostenspiegel-fuer-deutschland/", date: "2025-12"}
  Q43: {publisher: "ImmoScout24; IfW GREIX", title: "WohnBarometer Q2/2026; GREIX Q4/2025", url: "https://www.immobilienscout24.de/unternehmen/fileadmin/user_upload/WohnBarometer_Q2_2026_Miete.pdf", date: "2026-07"}
  Q44: {publisher: "Immowelt (TUM/VDI 2067)", title: "Lebensdauer Wärmepumpen", url: "https://www.immowelt.de/ratgeber/news/lebensdauer-von-waermepumpen-so-lange-halten-sie-im-vergleich-zu-oel-und-gasheizung", date: "2025"}
  Q45: {publisher: "BBSR/BNB", title: "Nutzungsdauern von Bauteilen 2017 (nicht abrufbar)", url: "https://www.nachhaltigesbauen.de/", date: "2017"}
  Q46: {publisher: "BMJ", title: "ImmoWertV 2021 Anlagen 1 und 3", url: "https://www.gesetze-im-internet.de/immowertv_2022/", date: "geltend"}
  Q47: {publisher: "BMJ", title: "BewG §§ 188, 256", url: "https://www.gesetze-im-internet.de/bewg/__188.html", date: "geltend"}
  Q48: {publisher: "vdp", title: "Indexveränderungen Q4/2025", url: "https://www.pfandbrief.de/wp-content/uploads/2026/02/Index-Veraenderungen_DE_Q4_2025.pdf", date: "2026-02"}
  Q49: {publisher: "Destatis", title: "Baugenehmigungen (Stand 18.02.2026)", url: "https://www.destatis.de/DE/Themen/Branchen-Unternehmen/Bauen/Tabellen/baugenehmigungen.html", date: "2026-02-18"}
  Q51: {publisher: "OIES/Goldman Sachs (Websuche)", title: "TTF-Ausblick 2026/27", url: "https://www.trend.az/world/4235829.html", date: "2026-10-16"}
  Q52: {publisher: "greenox/DUH (Websuche)", title: "KfW 458 ab 21.07.2026", url: "https://greenox-group.de/warmepumpe/", date: "2026-07"}
  Q53: {publisher: "vdiv/LTO (Websuche)", title: "Mietrecht 2026", url: "https://vdiv.de/news-details/mietrechtsreform-2026-deckel-fuer-indexmieten-und-neue-spielregeln-fuer-vermieter", date: "2026"}

# ===========================================================================
energy_prices:
  conversion:
    gas_hs_to_hi:
      label_de: "Umrechnung Erdgas Brennwert -> Heizwert"
      unit: "kWh_Hi/kWh_Hs"
      value: 0.903
      sources: [Q20]
      quality: "A"
    heating_oil_kwh_per_litre:
      label_de: "Heizwert Heizöl EL je Liter"
      unit: "kWh_Hi/l"
      value: 10.05
      sources: [Q20]
      quality: "A"
      note_de: "42,8 GJ/t x 0,845 kg/l"
    pellets_kwh_per_kg:
      label_de: "Heizwert Holzpellets"
      unit: "kWh_Hi/kg"
      value: 5.0
      dist: {type: "triangular", min: 4.6, mode: 5.0, max: 5.2}
      sources: [Q09]
      quality: "C"
    vat_energy:
      label_de: "Umsatzsteuersatz Energie (Gas, Strom, Fernwärme, Öl, Pellets)"
      unit: "1"
      value: 0.19
      quality: "A"

  price_gas_household:
    label_de: "Erdgaspreis Haushalt EFH (brutto, Hs)"
    unit: "ct/kWh"
    value: 12.0
    dist: {type: "triangular", min: 10.5, mode: 12.0, max: 15.5}
    price_basis: "brutto, Hs, inkl. CO2 65 EUR/t"
    as_of: "2026-08"
    sources: [Q02, Q03, Q05, Q11]
    quality: "B"
    volatility: "hoch"
    note_de: "BDEW 2026 bisher 11,93 ct; Aug. 2026 12,45 ct; Destatis 1. Hj 2026 11,58 ct; Aufwärtsrisiko 2027."
  price_gas_household_mfh:
    label_de: "Erdgaspreis je Haushalt im MFH (brutto, Hs)"
    unit: "ct/kWh"
    value: 11.2
    dist: {type: "triangular", min: 9.8, mode: 11.2, max: 14.5}
    as_of: "2026-08"
    sources: [Q02]
    quality: "B"
    volatility: "hoch"
  price_heating_oil:
    label_de: "Heizölpreis (brutto, Hi), 12-Monats-Mittel"
    unit: "ct/kWh"
    value: 14.0
    dist: {type: "triangular", min: 9.5, mode: 14.0, max: 19.0}
    as_of: "2026-10"
    sources: [Q04, Q06, Q08]
    quality: "C"
    volatility: "sehr hoch"
    note_de: "Spot 19.-25.10.2026: 171-174 EUR/100 l (= ca. 17,2 ct/kWh); Mittel 2025 ca. 9,3 ct/kWh."
  price_heating_oil_spot:
    label_de: "Heizölpreis Spot (brutto, Hi), Oktober 2026"
    unit: "ct/kWh"
    value: 17.2
    as_of: "2026-10-25"
    sources: [Q08]
    quality: "C"
    volatility: "sehr hoch"
  price_district_heating:
    label_de: "Fernwärmepreis Mischpreis MFH (brutto)"
    unit: "ct/kWh"
    value: 15.6
    dist: {type: "triangular", min: 12.5, mode: 15.6, max: 17.5}
    as_of: "2026-04-01"
    sources: [Q06, Q07]
    quality: "B"
    volatility: "mittel"
    note_de: "Netzspezifisch 8-36 ct/kWh; lokalen Preis eintragen."
  price_electricity_household:
    label_de: "Haushaltsstrompreis (brutto)"
    unit: "ct/kWh"
    value: 37.5
    dist: {type: "triangular", min: 32.0, mode: 37.5, max: 42.0}
    as_of: "2026-08"
    sources: [Q01, Q03, Q05]
    quality: "A"
    volatility: "mittel"
  price_electricity_heatpump:
    label_de: "Wärmepumpenstrom, separater Zähler (brutto)"
    unit: "ct/kWh"
    value: 26.0
    dist: {type: "triangular", min: 20.0, mode: 26.0, max: 31.0}
    as_of: "2026"
    sources: [Q05, Q39]
    quality: "D"
    volatility: "mittel"
    note_de: "BNetzA 01.04.2025: 27,44 ct (getrennte Messung); gemeinsame Messung 31,70 ct."
  price_wood_pellets:
    label_de: "Holzpelletpreis (brutto, Hi), 12-Monats-Mittel"
    unit: "ct/kWh"
    value: 8.5
    dist: {type: "triangular", min: 6.5, mode: 8.5, max: 10.5}
    as_of: "2026-10"
    sources: [Q09, Q10]
    quality: "C"
    volatility: "hoch"
    note_de: "DEPI Okt. 2026: 464,61 EUR/t = 9,29 ct/kWh; Mittel 2025: 343,01 EUR/t."
  price_gas_company_net:
    label_de: "Erdgas Zentralheizung MFH, netto (Hs)"
    unit: "ct/kWh"
    value: 9.4
    dist: {type: "triangular", min: 7.5, mode: 9.4, max: 12.0}
    sources: [Q02]
    quality: "D"
  price_district_heating_company_net:
    label_de: "Fernwärme MFH, netto"
    unit: "ct/kWh"
    value: 13.1
    dist: {type: "triangular", min: 10.5, mode: 13.1, max: 14.7}
    sources: [Q06]
    quality: "D"
  price_electricity_common_net:
    label_de: "Allgemeinstrom Wohnungsunternehmen, netto"
    unit: "ct/kWh"
    value: 27.0
    dist: {type: "triangular", min: 22.0, mode: 27.0, max: 33.0}
    sources: [Q01]
    quality: "D"
  price_electricity_heatpump_company_net:
    label_de: "WP-Strom Zentral-WP MFH, netto"
    unit: "ct/kWh"
    value: 21.0
    dist: {type: "triangular", min: 17.0, mode: 21.0, max: 26.0}
    sources: [Q05]
    quality: "D"
  price_pv_feed_in_small:
    label_de: "EEG-Einspeisevergütung Teileinspeisung bis 10 kWp (IBN ab 01.08.2026)"
    unit: "ct/kWh"
    value: 7.70
    valid_from: "2026-08-01"
    valid_to: "2026-12-31"
    sources: [Q41]
    quality: "C"
    note_de: "Volleinspeisung 12,22 ct/kWh; EEG-Novelle: Wegfall fester Vergütung für Neuanlagen ab 2027 geplant."

  normal_price_anchor:
    label_de: "Normalpreise (Anker der Mean-Reversion), real 2026, brutto, ohne CO2-Komponente"
    unit: "ct/kWh"
    quality: "D"
    gas: {value: 10.0, dist: {type: "triangular", min: 8.5, mode: 10.0, max: 12.0}}
    heating_oil: {value: 8.0, dist: {type: "triangular", min: 6.5, mode: 8.0, max: 10.5}}
    district_heating: {value: 15.0, dist: {type: "triangular", min: 12.5, mode: 15.0, max: 17.5}}
    electricity_household: {value: 36.0, dist: {type: "triangular", min: 30.0, mode: 36.0, max: 42.0}}
    electricity_heatpump: {value: 25.0, dist: {type: "triangular", min: 20.0, mode: 25.0, max: 30.0}}
    wood_pellets: {value: 7.0, dist: {type: "triangular", min: 5.5, mode: 7.0, max: 9.0}}

  dynamics:
    label_de: "Pfaddynamik Basispreise (log, AR(1) um Normalpreis + realen Trend)"
    model: "ar1_log_mean_reverting"
    quality: "D"
    note_de: "phi und sigma aus HVPI DE 1996-2025 (reale Log-Niveaus) geschätzt und gerundet; Trend je Pfad ziehen."
    gas: {phi: 0.78, sigma: 0.085, real_trend: {type: "normal", mean: 0.0, sd: 0.010}}
    heating_oil: {phi: 0.72, sigma: 0.180, real_trend: {type: "normal", mean: 0.0, sd: 0.012}}
    district_heating: {phi: 0.80, sigma: 0.070, real_trend: {type: "normal", mean: 0.005, sd: 0.008}}
    electricity_household: {phi: 0.78, sigma: 0.045, real_trend: {type: "normal", mean: 0.0, sd: 0.007}}
    electricity_heatpump: {phi: 0.78, sigma: 0.050, real_trend: {type: "normal", mean: 0.0, sd: 0.007}}
    wood_pellets: {phi: 0.60, sigma: 0.090, real_trend: {type: "normal", mean: 0.005, sd: 0.008}}
  scenarios_real_trend:
    label_de: "Deterministische Szenarien realer Basispreistrend (ohne CO2), Anteil p.a."
    unit: "1/a"
    quality: "D"
    low: {gas: -0.010, heating_oil: -0.010, electricity: -0.005, district_heating: 0.000, wood_pellets: 0.000}
    mid: {gas: 0.000, heating_oil: 0.000, electricity: 0.000, district_heating: 0.005, wood_pellets: 0.005}
    high: {gas: 0.015, heating_oil: 0.015, electricity: 0.010, district_heating: 0.020, wood_pellets: 0.015}
  historical_stats_2001_2025:
    label_de: "Jährliche Log-Änderungen HVPI DE 2001-2025 (nominal): Mittel / Std.-Abw."
    sources: [Q12]
    quality: "A"
    cpi: {mean: 0.0206, sd: 0.0174}
    electricity: {mean: 0.0407, sd: 0.0481}
    gas: {mean: 0.0458, sd: 0.1023}
    heating_oil: {mean: 0.0247, sd: 0.2009}
    solid_fuels: {mean: 0.0270, sd: 0.0925}
    district_heating: {mean: 0.0484, sd: 0.0819}

# ===========================================================================
co2:
  behg_price_history:
    label_de: "BEHG-Preise (Fest-/Korridorpreise)"
    unit: "EUR/t"
    sources: [Q14, Q06, Q18]
    quality: "A"
    path: {2021: 25, 2022: 30, 2023: 30, 2024: 45, 2025: 55, 2026: 65}
    note_de: "2026 Korridor 55-65, 1. Versteigerung 01.07.2026 zu 65 EUR/t; 2027 Korridor 55-65 laut Kabinettsentwurf (noch nicht in Kraft)."
  co2_price_paths:
    label_de: "CO2-Preispfade Gebäude (BEHG bis 2027, ab 2028 EU-ETS 2), nominal"
    unit: "EUR/t"
    sources: [Q14, Q15, Q16, Q17]
    quality: "D"
    default_scenario: "mid"
    interpolation: "linear"
    mc_sampling_de: "komonoton: ein Quantil u je Pfad, Dreiecksverteilung (low, mid, high) je Stützjahr; optional Lärmterm sigma 0,10"
    low: {2026: 65, 2027: 55, 2028: 45, 2030: 55, 2032: 60, 2035: 75, 2040: 100, 2045: 120, 2050: 140}
    mid: {2026: 65, 2027: 65, 2028: 60, 2030: 75, 2032: 90, 2035: 130, 2040: 170, 2045: 210, 2050: 250}
    high: {2026: 65, 2027: 80, 2028: 95, 2030: 125, 2032: 155, 2035: 200, 2040: 275, 2045: 350, 2050: 425}
    note_de: "high = UBA-Rahmendaten Projektionen 2026; mid = Analystenerwartung nach MSR-Reform plus eigene Extrapolation; low = Preisdämpfung PSM (45 EUR2020)."
  ets2_price_stability:
    label_de: "ETS2-Preisstabilitätsmechanismus (Auslöser)"
    trigger_eur_2020: 45
    trigger_nominal_2027_approx: 56
    release_volume_mt: 40
    sources: [Q15, Q16]
    quality: "B"
  emission_factors_behg:
    label_de: "Emissionsfaktoren für CO2-Kosten (EBeV 2030 Anlage 2)"
    unit: "kg CO2/kWh"
    sources: [Q20]
    quality: "A"
    natural_gas_hs: 0.1814
    natural_gas_hi: 0.2009
    heating_oil_hi: 0.2664
    lpg_hi: 0.2358
    wood: 0.0
    note_de: "Erdgas 0,0558 t/GJ, 3,2508 GJ/MWh_Hs; Heizöl EL 0,074 t/GJ; Flüssiggas 0,0655 t/GJ."
  emission_factors_geg_anlage9:
    label_de: "Emissionsfaktoren GEG/GModG Anlage 9 (Energieausweis)"
    unit: "g CO2-Aeq/kWh"
    valid_from: "2023-01-01"
    valid_to: "2026-12-31"
    sources: [Q19]
    quality: "A"
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
    district_heating_chp_coal: 300
    district_heating_chp_gas_oil: 180
    district_heating_chp_renewable: 40
    district_heating_boiler_coal: 400
    district_heating_boiler_gas_oil: 300
    district_heating_boiler_renewable: 60
    note_de: "Neufassung durch G. v. 23.07.2026 (BGBl. 2026 I Nr. 226) ab 2027; neue Werte unverifiziert (Hinweis Strom 100 g/kWh)."
  co2_cost_split_landlord:
    label_de: "CO2KostAufG Stufenmodell Wohngebäude: Vermieteranteil nach kg CO2/(m2 Wfl. a)"
    sources: [Q21, Q19c]
    quality: "C"
    rule_default: "stufenmodell_2023"
    stufenmodell_2023:
      - {upper_kg_m2a: 12, landlord_share: 0.00}
      - {upper_kg_m2a: 17, landlord_share: 0.10}
      - {upper_kg_m2a: 22, landlord_share: 0.20}
      - {upper_kg_m2a: 27, landlord_share: 0.30}
      - {upper_kg_m2a: 32, landlord_share: 0.40}
      - {upper_kg_m2a: 37, landlord_share: 0.50}
      - {upper_kg_m2a: 42, landlord_share: 0.60}
      - {upper_kg_m2a: 47, landlord_share: 0.70}
      - {upper_kg_m2a: 52, landlord_share: 0.80}
      - {upper_kg_m2a: .inf, landlord_share: 0.95}
    haelftig_ab_2028:
      landlord_share: 0.50
      valid_from: "2028-01-01"
      note_de: "Laut GÖRG (17.07.2026) GModG-Regel: CO2-Kosten und Gasnetzentgelte 50/50; Anwendungsbereich prüfen."

# ===========================================================================
rates:
  rate_mortgage_10y_plus:
    label_de: "Effektivzins Wohnungsbaukredit, Zinsbindung > 10 Jahre (private Haushalte)"
    unit: "%/a"
    value: 4.1
    dist: {type: "triangular", min: 3.5, mode: 4.1, max: 5.0}
    as_of: "2026-10"
    sources: [Q22, Q24]
    quality: "A"
    volatility: "mittel"
    note_de: "Bundesbank SUD119 Aug. 2026: 4,04 %; Dr. Klein Topzins ab 4,16 % (13.10.2026)."
  rate_mortgage_5_10y:
    label_de: "Effektivzins Wohnungsbaukredit, Zinsbindung 5-10 Jahre"
    unit: "%/a"
    value: 3.85
    dist: {type: "triangular", min: 3.3, mode: 3.85, max: 4.8}
    as_of: "2026-08"
    sources: [Q22]
    quality: "A"
  rate_company_loan_long:
    label_de: "Langfristiger Darlehenszins Wohnungsunternehmen (10 J.)"
    unit: "%/a"
    value: 3.9
    dist: {type: "triangular", min: 3.3, mode: 3.9, max: 4.8}
    as_of: "2026-08"
    sources: [Q22]
    quality: "D"
    note_de: "MFI NFC 0,25-1 Mio. > 10 J.: 3,86 % (besichert 3,24 %)."
  rate_overdraft_company:
    label_de: "Kontokorrent-/Betriebsmittelkredit Unternehmen"
    unit: "%/a"
    value: 5.1
    dist: {type: "triangular", min: 4.0, mode: 5.1, max: 7.0}
    as_of: "2026-08"
    sources: [Q22]
    quality: "A"
  rate_overdraft_household:
    label_de: "Dispositionskredit private Haushalte"
    unit: "%/a"
    value: 9.5
    dist: {type: "triangular", min: 8.0, mode: 9.5, max: 12.0}
    as_of: "2026-08"
    sources: [Q22]
    quality: "A"
  rate_deposit:
    label_de: "Habenzins Geldanlage (Festgeld bis 1 Jahr)"
    unit: "%/a"
    value: 2.25
    dist: {type: "triangular", min: 0.5, mode: 2.25, max: 3.5}
    as_of: "2026-08"
    sources: [Q22]
    quality: "A"
    note_de: "Tagesgeld HH Durchschnitt 0,51 %; Festgeld 1-2 J. 2,64 %, > 2 J. 2,72 %."
  yield_bund_10y:
    label_de: "Rendite Bundesanleihe 10 Jahre (Svensson)"
    unit: "%/a"
    value: 3.4
    as_of: "2026-10-23"
    sources: [Q22]
    quality: "A"
  yield_bund_1y:
    label_de: "Rendite Bundeswertpapier 1 Jahr (Svensson)"
    unit: "%/a"
    value: 3.0
    as_of: "2026-09"
    sources: [Q22]
    quality: "A"
  ecb_deposit_rate:
    label_de: "EZB-Einlagesatz"
    unit: "%/a"
    value: 2.50
    as_of: "2026-09"
    sources: [Q22]
    quality: "A"
  kfw_conditions_snapshot:
    label_de: "KfW-Sollzinsen (Effektivzins in Klammern im Memo), Stand 22.10.2026"
    unit: "%/a"
    as_of: "2026-10-22"
    sources: [Q23]
    quality: "A"
    volatility: "hoch"
    kfw_261_20y_3_10: 3.53
    kfw_261_30y_5_10: 3.65
    kfw_297_298_standard_25y_3_10: 2.81
    kfw_297_298_standard_35y_5_10: 2.94
    kfw_297_298_eh55_25y_3_10: 2.03
    kfw_297_298_eh55_35y_5_10: 2.19
    kfw_300_308_35y_5_10: 1.00
    kfw_124_35y_5_10: 4.56
    kfw_159_30y_5_10: 3.96
    kfw_358_35y_5_10: 2.68
    kfw_359_35y_5_10: 4.63
  interest_model:
    label_de: "Zinsmodell: Vasicek auf Bund 10 J. plus AR(1)-Spreads"
    model: "vasicek_annual"
    quality: "D"
    sources: [Q22]
    r0: 0.034
    theta: {value: 0.028, dist: {type: "triangular", min: 0.020, mode: 0.028, max: 0.035}}
    kappa: {value: 0.12, dist: {type: "triangular", min: 0.06, mode: 0.12, max: 0.20}}
    sigma: {value: 0.0075, dist: {type: "triangular", min: 0.0055, mode: 0.0075, max: 0.0095}}
    floor: -0.01
    spread_mortgage: {mean: 0.010, start: 0.007, phi: 0.7, sigma: 0.002, min: 0.004, max: 0.020}
    spread_company_loan: {mean: 0.0075, start: 0.005, phi: 0.7, sigma: 0.002}
    term_spread_10y_1y: {mean: 0.011, note_de: "Bund 10 J. minus 1 J., Mittel 1973-2025"}
    spread_deposit_over_1y: {mean: -0.003, sigma: 0.003}
    spread_overdraft_company_over_1y: {mean: 0.025}
    corr_with_inflation_innovation: 0.45
    historical_estimates:
      bund10_1973_2025: {mean: 0.0501, kappa: 0.049, theta: 0.0239, sigma: 0.0080, sd_annual_change: 0.0079}
      bund10_1990_2025: {mean: 0.0362, kappa: 0.089, theta: 0.0159, sigma: 0.0061, sd_annual_change: 0.0062}
      mortgage10_2003_2025: {mean: 0.0329, kappa: 0.131, theta: 0.0274, sigma: 0.0054, sd_annual_change: 0.0053}
      spread_mortgage10_bund10_2003_2026: {mean: 0.0121, sd: 0.0040, min: 0.0037, max: 0.0213}

# ===========================================================================
macro:
  inflation_cpi:
    label_de: "Inflationsrate VPI"
    unit: "1/a"
    sources: [Q04, Q25, Q26, Q12]
    quality: "B"
    path: {2026: 0.030, 2027: 0.026, 2028: 0.021, 2029: 0.020}
    long_run: {value: 0.020, dist: {type: "triangular", min: 0.015, mode: 0.020, max: 0.030}}
    dynamics: {model: "ar1", mu: 0.020, phi: 0.55, sigma: 0.0145, start: 0.030}
    note_de: "VPI Sept. 2026 +3,3 %; Bundesbank Juni 2026 HVPI 2,9/2,7/1,9 %; EZB Sept. 2026 (Euroraum) 3,0/2,5/2,1 %."
  construction_price_growth:
    label_de: "Baupreissteigerung Wohngebäude (Neubau)"
    unit: "1/a"
    sources: [Q13, Q27, Q28]
    quality: "B"
    path: {2026: 0.050, 2027: 0.035}
    long_run_spread_over_cpi: {value: 0.0075, dist: {type: "triangular", min: 0.0, mode: 0.0075, max: 0.020}}
    dynamics: {corr_with_cpi: 0.70, idiosyncratic_sigma: 0.015}
    note_de: "Aug. 2026 +5,5 % ggü. Vorjahr; 2000-2025 3,1 % p.a. (real +1,0 %)."
  maintenance_cost_growth:
    label_de: "Kostensteigerung Instandhaltung/Sanierung"
    unit: "1/a"
    sources: [Q12, Q27]
    quality: "B"
    path: {2026: 0.055, 2027: 0.040}
    long_run_spread_over_cpi: {value: 0.010, dist: {type: "triangular", min: 0.0, mode: 0.010, max: 0.020}}
  rent_growth_existing:
    label_de: "Mietsteigerung Bestandsmieten (nominal)"
    unit: "1/a"
    value: 0.0175
    dist: {type: "triangular", min: 0.005, mode: 0.0175, max: 0.030}
    sources: [Q12, Q33, Q04]
    quality: "B"
    volatility: "niedrig"
    note_de: "VPI-Nettokaltmieten 2000-2025 +1,35 % p.a. (sd 0,35 Pp); GdW 2010-2024 +2,2 % p.a.; Sept. 2026 +1,9 %."
  rent_growth_market:
    label_de: "Mietsteigerung Neuvertrags-/Marktmieten (nominal)"
    unit: "1/a"
    value: 0.025
    dist: {type: "triangular", min: 0.0, mode: 0.025, max: 0.050}
    sources: [Q43, Q48]
    quality: "C"
    note_de: "IS24 Q2/2026: Bestand +2,7 %, Neubau +1,8 %; GREIX Q4/2025 +4,5 %; vdp Neuvertragsmieten Q4/2025 +3,5 %."
  operating_cost_growth:
    label_de: "Steigerung kalte Betriebskosten"
    unit: "1/a"
    long_run_spread_over_cpi: {value: 0.005, dist: {type: "triangular", min: 0.0, mode: 0.005, max: 0.015}}
    sources: [Q33, Q42]
    quality: "D"
  correlation_innovations:
    label_de: "Empfohlene (geschrumpfte) Korrelationsmatrix der jährlichen Innovationen"
    quality: "D"
    sources: [Q12, Q13, Q22]
    order: [cpi, gas, heating_oil, electricity, district_heating, wood_pellets, construction, rent, bund10]
    matrix:
      - [1.00, 0.55, 0.40, 0.40, 0.40, 0.45, 0.60, 0.30, 0.45]
      - [0.55, 1.00, 0.35, 0.45, 0.50, 0.45, 0.40, 0.05, 0.35]
      - [0.40, 0.35, 1.00, 0.30, 0.25, 0.35, 0.30, 0.00, 0.20]
      - [0.40, 0.45, 0.30, 1.00, 0.20, 0.50, 0.35, 0.00, 0.30]
      - [0.40, 0.50, 0.25, 0.20, 1.00, 0.20, 0.25, 0.10, 0.20]
      - [0.45, 0.45, 0.35, 0.50, 0.20, 1.00, 0.45, 0.00, 0.35]
      - [0.60, 0.40, 0.30, 0.35, 0.25, 0.45, 1.00, 0.30, 0.45]
      - [0.30, 0.05, 0.00, 0.00, 0.10, 0.00, 0.30, 1.00, 0.30]
      - [0.45, 0.35, 0.20, 0.30, 0.20, 0.35, 0.45, 0.30, 1.00]
    note_de: "Rohkorrelationen 2001-2025 um ca. 30-40 % geschrumpft; im Code positive Definitheit prüfen."

# ===========================================================================
costs_newbuild:
  cost_newbuild_mfh_kg300_400:
    label_de: "Bauwerkskosten Neubau MFH (KG 300+400) je m2 Wohnfläche, brutto"
    unit: "EUR/m2"
    value: 3750
    dist: {type: "triangular", min: 3000, mode: 3750, max: 5000}
    as_of: "2026"
    sources: [Q28]
    quality: "B"
    note_de: "ARGE Q4/2025 Median Großstädte im Intervall 3.500-3.750 EUR/m2; +4 % Fortschreibung."
  cost_newbuild_mfh_kg200_700:
    label_de: "Herstellungskosten Neubau MFH ohne Grundstück (KG 200-700), brutto"
    unit: "EUR/m2"
    value: 4800
    dist: {type: "triangular", min: 3300, mode: 4800, max: 8600}
    as_of: "2026"
    sources: [Q28]
    quality: "B"
  share_kg700_of_kg300_400:
    label_de: "Baunebenkosten KG 700 in % der KG 300+400"
    unit: "1"
    value: 0.20
    dist: {type: "triangular", min: 0.15, mode: 0.20, max: 0.25}
    sources: [Q28]
    quality: "D"
  share_kg200_500_600_of_kg300_400:
    label_de: "Erschließung, Außenanlagen, Ausstattung in % der KG 300+400"
    unit: "1"
    value: 0.06
    dist: {type: "triangular", min: 0.03, mode: 0.06, max: 0.10}
    quality: "D"
  cost_newbuild_efh_kg300_400:
    label_de: "Bauwerkskosten Neubau EFH (KG 300+400) je m2 Wohnfläche, brutto"
    unit: "EUR/m2"
    value: 3000
    dist: {type: "triangular", min: 2300, mode: 3000, max: 4000}
    sources: [Q49]
    quality: "D"
  surcharge_eh40_vs_minimum:
    label_de: "Mehrkosten EH 40 ggü. Mindeststandard (Anteil KG 300+400)"
    unit: "1"
    value: 0.05
    dist: {type: "triangular", min: 0.03, mode: 0.05, max: 0.08}
    quality: "D"

# ===========================================================================
costs_retrofit:
  index_factor_2023_to_2026:
    label_de: "Fortschreibungsfaktor IWU-Kostenfunktionen Preisstand 2023 -> 2026"
    unit: "1"
    value: 1.12
    dist: {type: "triangular", min: 1.09, mode: 1.12, max: 1.16}
    sources: [Q13, Q27, Q29]
    quality: "D"
  envelope_cost_functions_2026:
    label_de: "Kostenfunktionen Gebäudehülle 2026 (brutto): Kosten = a + b * Dämmdicke_cm, je m2 Bauteilfläche"
    unit: "EUR/m2"
    sources: [Q29]
    quality: "B"
    etics_full: {a: 169.6, b: 4.92}
    etics_energy_related: {a: 36.2, b: 5.15}
    cavity_insulation: {a: 18.7, b: 2.98}
    basement_ceiling_no_cladding: {a: 55.1, b: 2.24}
    basement_ceiling_with_cladding: {a: 97.3, b: 2.78}
    basement_ceiling_top_side: {a: 16.2, b: 2.93}
    pitched_roof_full: {a: 291.8, b: 5.35}
    pitched_roof_energy_related: {a: 21.9, b: 4.59}
    pitched_roof_retrofit_only: {a: 63.3, b: 4.49}
    flat_roof_full: {a: 199.9, b: 7.88}
    flat_roof_energy_related: {a: 41.6, b: 5.58}
    top_ceiling_walkable: {a: 52.3, b: 3.33}
    top_ceiling_not_walkable: {a: 6.9, b: 1.98}
  window_cost_2026:
    label_de: "Fenster: Vollkosten und energiebedingte Mehrkosten (brutto)"
    unit: "EUR/m2 Fensterfläche"
    sources: [Q29]
    quality: "D"
    full_cost_triple_glazing: {value: 850, dist: {type: "triangular", min: 600, mode: 850, max: 1300}}
    extra_cost_2wsv_to_3wsv_mfh: {a: 112.9, exponent: -0.255, x: "Fenstergröße m2/Stück"}
    extra_cost_2wsv_to_3wsv_efh: {a: 103.2, exponent: -0.191, x: "Fenstergröße m2/Stück"}
    extra_cost_2wsv_to_passive_mfh: {a: 402.2, exponent: -0.136, x: "Fenstergröße m2/Stück"}
  door_cost_2026:
    label_de: "Haustür Vollkosten (brutto)"
    unit: "EUR/m2 Türfläche"
    sources: [Q29]
    quality: "B"
    mfh: 2237
    efh: 2623
  system_cost_functions_2026:
    label_de: "Kostenfunktionen Anlagentechnik 2026 (brutto): spezifische Kosten = a * A_N^exponent (EUR/m2 A_N)"
    unit: "EUR/m2 A_N"
    sources: [Q29]
    quality: "B"
    note_de: "A_N = Gebäudenutzfläche (ca. 1,2-1,35 x Wohnfläche); Gesamtkosten = spez. Kosten x A_N."
    gas_condensing_boiler: {a: 1734.7, exponent: -0.518}
    district_heating_substation: {a: 1270.3, exponent: -0.487}
    district_heating_connection: {a: 1024.7, exponent: -0.614}
    gas_connection: {a: 299.1, exponent: -0.49}
    pellet_boiler: {a: 4850.9, exponent: -0.587}
    oil_boiler: {a: 2304.5, exponent: -0.536}
    heating_distribution: {a: 1277.6, exponent: -0.533}
    ventilation_central_hr: {a: 693.9, exponent: -0.364}
    ventilation_decentral_hr: {a: 1510.8, exponent: -0.652}
    exhaust_ventilation: {a: 1936.3, exponent: -0.78}
    solar_thermal_dhw_with_new_boiler: {a: 2095.9, exponent: -0.489}
    architect_fees: {a: 1337.8, exponent: -0.599}
    energy_advice: {a: 26.7, exponent: -0.339}
  cost_hp_air_water_efh:
    label_de: "Luft/Wasser-Wärmepumpe EFH inkl. Installation, brutto"
    unit: "EUR"
    value: 32000
    dist: {type: "triangular", min: 22000, mode: 32000, max: 50000}
    sources: [Q39]
    quality: "C"
  cost_hp_brine_water_efh:
    label_de: "Sole/Wasser-Wärmepumpe EFH inkl. Erdsonden, brutto"
    unit: "EUR"
    value: 45000
    dist: {type: "triangular", min: 35000, mode: 45000, max: 60000}
    sources: [Q39]
    quality: "C"
  cost_borehole_per_m:
    label_de: "Erdsondenbohrung je Meter, brutto"
    unit: "EUR/m"
    value: 110
    dist: {type: "triangular", min: 80, mode: 110, max: 150}
    quality: "D"
  cost_hp_mfh_per_kw:
    label_de: "Wärmepumpenanlage MFH je kW thermisch, brutto"
    unit: "EUR/kW"
    value: 1800
    dist: {type: "triangular", min: 1200, mode: 1800, max: 2800}
    quality: "D"
  cost_pv_small_per_kwp:
    label_de: "PV-Anlage bis 30 kWp (USt 0 %)"
    unit: "EUR/kWp"
    value: 1350
    dist: {type: "triangular", min: 1000, mode: 1350, max: 1800}
    sources: [Q40]
    quality: "C"
  cost_pv_mfh_per_kwp_net:
    label_de: "PV-Anlage MFH 30-100 kWp, netto"
    unit: "EUR/kWp"
    value: 1100
    dist: {type: "triangular", min: 850, mode: 1100, max: 1500}
    sources: [Q40]
    quality: "D"
  cost_battery_per_kwh:
    label_de: "Batteriespeicher"
    unit: "EUR/kWh"
    value: 550
    dist: {type: "triangular", min: 300, mode: 550, max: 800}
    sources: [Q40]
    quality: "D"
  cost_inverter_replacement_per_kwp:
    label_de: "Wechselrichtertausch"
    unit: "EUR/kWp"
    value: 150
    dist: {type: "triangular", min: 100, mode: 150, max: 250}
    quality: "D"
  pv_specific_yield:
    label_de: "Spezifischer PV-Ertrag"
    unit: "kWh/(kWp a)"
    value: 950
    dist: {type: "triangular", min: 800, mode: 950, max: 1100}
    quality: "D"
  cost_retrofit_package:
    label_de: "Komplettsanierung je m2 Wohnfläche (brutto, inkl. KG 700, ohne Förderung) - nur Plausibilisierung"
    unit: "EUR/m2"
    quality: "D"
    eh85: {value: 750, dist: {type: "triangular", min: 500, mode: 750, max: 1100}, ohnehin_share: 0.40}
    eh70: {value: 1050, dist: {type: "triangular", min: 750, mode: 1050, max: 1500}, ohnehin_share: 0.40}
    eh55: {value: 1350, dist: {type: "triangular", min: 950, mode: 1350, max: 1900}, ohnehin_share: 0.35}
  ohnehin_share:
    label_de: "Ohnehin-Anteil (Instandsetzungsanteil) an Vollkosten bei fälliger Erneuerung"
    unit: "1"
    sources: [Q29]
    quality: "D"
    etics: {value: 0.50, dist: {type: "triangular", min: 0.40, mode: 0.50, max: 0.65}}
    pitched_roof: {value: 0.70, dist: {type: "triangular", min: 0.60, mode: 0.70, max: 0.80}}
    flat_roof: {value: 0.57, dist: {type: "triangular", min: 0.45, mode: 0.57, max: 0.65}}
    windows: {value: 0.85, dist: {type: "triangular", min: 0.75, mode: 0.85, max: 0.90}}
    basement_ceiling: {value: 0.0}
    top_ceiling: {value: 0.0}
    ventilation: {value: 0.0}
    rule_de: "Ohnehin nur bei Restnutzungsdauer <= 5 J. voll ansetzen, sonst anteilig nach Restwert."

# ===========================================================================
demand:
  typology_calibrated:
    label_de: "IWU-Typologie, kalibriert auf typisches Verbrauchsniveau, Gas-Zentralheizung, Endenergie fossil Heizung+WW (Hs) und Heizwärme q_h"
    unit: "kWh/(m2 a)"
    sources: [Q30]
    quality: "B"
    note_de: "Ist = unmodernisierter Originalzustand; MP1 konventionell; MP2 zukunftsweisend; Bezug beheizte Wohnfläche."
    efh:
      EFH_A_bis1859: {ist_qh: 184, ist_end: 270}
      EFH_B_1860_1918: {ist_qh: 181, ist_end: 267, mp1_qh: 105, mp1_end: 144, mp2_qh: 42, mp2_end: 53}
      EFH_C_1919_1948: {ist_qh: 164, ist_end: 249, mp1_qh: 92, mp1_end: 131, mp2_qh: 34, mp2_end: 44}
      EFH_D_1949_1957: {ist_qh: 182, ist_end: 268, mp1_qh: 123, mp1_end: 162, mp2_qh: 47, mp2_end: 58}
      EFH_E_1958_1968: {ist_qh: 180, ist_end: 266, mp1_qh: 129, mp1_end: 168, mp2_qh: 57, mp2_end: 68}
      EFH_F_1969_1978: {ist_qh: 153, ist_end: 237, mp1_qh: 99, mp1_end: 138, mp2_qh: 43, mp2_end: 54}
      EFH_G_1979_1983: {ist_qh: 120, ist_end: 200, mp1_qh: 82, mp1_end: 121, mp2_qh: 28, mp2_end: 38}
      EFH_H_1984_1994: {ist_qh: 132, ist_end: 214, mp1_qh: 104, mp1_end: 143, mp2_qh: 42, mp2_end: 53}
      EFH_I_1995_2001: {ist_qh: 122, ist_end: 160, mp1_qh: 107, mp1_end: 122, mp2_qh: 43, mp2_end: 54}
      EFH_J_2002_2009: {ist_qh: 87, ist_end: 125, mp1_qh: 80, mp1_end: 92, mp2_qh: 40, mp2_end: 50}
    mfh:
      MFH_A_bis1859: {ist_qh: 189, ist_end: 268}
      MFH_B_1860_1918: {ist_qh: 145, ist_end: 222, mp1_qh: 89, mp1_end: 125, mp2_qh: 22, mp2_end: 45}
      MFH_C_1919_1948: {ist_qh: 166, ist_end: 245, mp1_qh: 91, mp1_end: 128, mp2_qh: 30, mp2_end: 54}
      MFH_D_1949_1957: {ist_qh: 154, ist_end: 232, mp1_qh: 87, mp1_end: 124, mp2_qh: 30, mp2_end: 54}
      MFH_E_1958_1968: {ist_qh: 127, ist_end: 204, mp1_qh: 74, mp1_end: 111, mp2_qh: 21, mp2_end: 45}
      MFH_F_1969_1978: {ist_qh: 131, ist_end: 209, mp1_qh: 81, mp1_end: 118, mp2_qh: 26, mp2_end: 50}
      MFH_G_1979_1983: {ist_qh: 115, ist_end: 192, mp1_qh: 75, mp1_end: 112, mp2_qh: 23, mp2_end: 47}
      MFH_H_1984_1994: {ist_qh: 119, ist_end: 196, mp1_qh: 80, mp1_end: 117, mp2_qh: 26, mp2_end: 50}
      MFH_I_1995_2001: {ist_qh: 100, ist_end: 137, mp1_qh: 76, mp1_end: 94, mp2_qh: 26, mp2_end: 43}
      MFH_J_2002_2009: {ist_qh: 64, ist_end: 100, mp1_qh: 59, mp1_end: 77, mp2_qh: 23, mp2_end: 40}
  newbuild_demand:
    label_de: "Neubau Mindeststandard (ca. EH 55) mit Wärmepumpe"
    unit: "kWh/(m2 a)"
    quality: "D"
    heating_demand_qh: {value: 40, dist: {type: "triangular", min: 30, mode: 40, max: 50}}
    dhw_useful_energy_efh: 12.5
    dhw_useful_energy_mfh: 16.0
    heatpump_electricity: {value: 18, dist: {type: "triangular", min: 14, mode: 18, max: 24}}
  prebound_factor:
    label_de: "Verhältnis Verbrauch/rechnerischer Bedarf unsanierter Gebäude"
    unit: "1"
    value: 0.65
    dist: {type: "triangular", min: 0.55, mode: 0.65, max: 0.85}
    quality: "D"
  jaz:
    label_de: "Jahresarbeitszahlen Wärmepumpen"
    unit: "1"
    sources: [Q38]
    air_water_existing: {value: 3.2, dist: {type: "triangular", min: 2.6, mode: 3.2, max: 4.0}, quality: "C"}
    ground_existing: {value: 4.0, dist: {type: "triangular", min: 3.4, mode: 4.0, max: 4.8}, quality: "C"}
    air_water_newbuild: {value: 3.8, dist: {type: "triangular", min: 3.2, mode: 3.8, max: 4.5}, quality: "D"}
    air_water_mfh_central: {value: 2.9, dist: {type: "triangular", min: 2.4, mode: 2.9, max: 3.5}, quality: "D"}
    degradation_per_year: {value: 0.003, dist: {type: "triangular", min: 0.0, mode: 0.003, max: 0.01}, quality: "D"}

# ===========================================================================
operating_costs:
  iibv_2026:
    label_de: "II. BV Pauschalen ab 01.01.2026 (Kostenmiete)"
    valid_from: "2026-01-01"
    valid_to: "2028-12-31"
    sources: [Q31]
    quality: "B"
    admin_per_unit_eur: 372.46
    admin_per_garage_eur: 48.58
    maintenance_lt22y_eur_m2: 11.50
    maintenance_ge22y_eur_m2: 14.58
    maintenance_ge32y_eur_m2: 18.62
    deduction_commercial_heat_supply_eur_m2: -0.31
    surcharge_elevator_eur_m2: 1.63
    deduction_small_repairs_by_tenant_eur_m2: -1.70
    cosmetic_repairs_by_landlord_eur_m2: 13.75
    maintenance_per_garage_eur: 110.13
    rent_loss_risk_share: 0.02
  immowertv_2026:
    label_de: "ImmoWertV Anlage 3 Modellansätze 2026"
    valid_from: "2026-01-01"
    valid_to: "2026-12-31"
    sources: [Q32, Q46]
    quality: "B"
    admin_per_unit_or_efh_eur: 367
    admin_per_condo_eur: 439
    admin_per_garage_eur: 48
    maintenance_eur_m2: 14.4
    maintenance_per_garage_eur: 108
    rent_loss_risk_share_residential: 0.02
    rent_loss_risk_share_commercial: 0.04
    admin_commercial_share_of_gross_rent: 0.03
  operating_cost_benchmarks:
    label_de: "Betriebskosten-Benchmarks"
    unit: "EUR/(m2 Monat)"
    sources: [Q42, Q33]
    quality: "C"
    total_dmb_2024: 2.67
    heating_dhw_dmb_2024: {value: 1.32, min: 0.46, max: 2.18}
    cold_gdw_2024: 1.90
    warm_gdw_2024: 1.64
  opex_nonrecoverable_share:
    label_de: "Nicht umlagefähige Bewirtschaftungskosten (Anteil Nettokaltmiete)"
    unit: "1"
    value: 0.01
    dist: {type: "triangular", min: 0.005, mode: 0.01, max: 0.025}
    quality: "D"
  maintenance_selfuser_share_of_construction_cost:
    label_de: "Instandhaltung Selbstnutzer (Anteil Herstellungskosten p.a.)"
    unit: "1/a"
    value: 0.012
    dist: {type: "triangular", min: 0.008, mode: 0.012, max: 0.018}
    quality: "D"

# ===========================================================================
lifetimes:
  label_de: "Nutzungsdauern (Jahre)"
  unit: "a"
  sources: [Q44, Q45, Q46]
  hp_air_water: {value: 18, dist: {type: "triangular", min: 15, mode: 18, max: 22}, quality: "C"}
  hp_brine_water: {value: 20, dist: {type: "triangular", min: 17, mode: 20, max: 25}, quality: "C"}
  borehole: {value: 50, dist: {type: "triangular", min: 40, mode: 50, max: 60}, quality: "D"}
  gas_boiler: {value: 18, dist: {type: "triangular", min: 15, mode: 18, max: 25}, quality: "C"}
  pellet_boiler: {value: 20, dist: {type: "triangular", min: 15, mode: 20, max: 25}, quality: "D"}
  district_heating_substation: {value: 25, dist: {type: "triangular", min: 20, mode: 25, max: 30}, quality: "D"}
  etics: {value: 40, dist: {type: "triangular", min: 30, mode: 40, max: 50}, quality: "D"}
  windows: {value: 40, dist: {type: "triangular", min: 30, mode: 40, max: 50}, quality: "D"}
  roof_pitched_covering: {value: 50, dist: {type: "triangular", min: 40, mode: 50, max: 70}, quality: "D"}
  roof_flat_sealing: {value: 30, dist: {type: "triangular", min: 20, mode: 30, max: 35}, quality: "D"}
  insulation_roof_ceiling: {value: 50, dist: {type: "triangular", min: 40, mode: 50, max: 60}, quality: "D"}
  pv_modules: {value: 25, dist: {type: "triangular", min: 20, mode: 25, max: 30}, quality: "D"}
  pv_inverter: {value: 12, dist: {type: "triangular", min: 10, mode: 12, max: 15}, quality: "D"}
  battery: {value: 12, dist: {type: "triangular", min: 10, mode: 12, max: 15}, quality: "D"}
  ventilation_central: {value: 20, dist: {type: "triangular", min: 15, mode: 20, max: 25}, quality: "D"}
  ventilation_decentral: {value: 15, dist: {type: "triangular", min: 12, mode: 15, max: 20}, quality: "D"}
  heating_distribution: {value: 40, dist: {type: "triangular", min: 30, mode: 40, max: 50}, quality: "D"}
  building_total_immowertv: {value: 80, quality: "B", note_de: "ImmoWertV 2021 Anlage 1, Wohngebäude"}
  maintenance_share_of_investment:
    label_de: "Instandsetzung + Wartung in % der Investition p.a. (VDI-2067-Größenordnung, zu prüfen)"
    unit: "1/a"
    quality: "D"
    heat_pump: {repair: 0.010, service: 0.015}
    gas_boiler: {repair: 0.010, service: 0.020}
    pellet_boiler: {repair: 0.020, service: 0.030}
    ventilation: {repair: 0.015, service: 0.020}
    pv_system: {total: 0.012}
    district_heating_substation: {repair: 0.010, service: 0.010}

# ===========================================================================
valuation_transaction:
  cap_rate_residential:
    label_de: "Liegenschaftszinssatz Mehrfamilienhaus nach Lage-Preset"
    unit: "1"
    sources: [Q32, Q47, Q48]
    quality: "D"
    a_metropolis: {value: 0.025, dist: {type: "triangular", min: 0.015, mode: 0.025, max: 0.035}}
    large_city: {value: 0.030, dist: {type: "triangular", min: 0.022, mode: 0.030, max: 0.040}}
    mid_city: {value: 0.035, dist: {type: "triangular", min: 0.025, mode: 0.035, max: 0.045}}
    rural_shrinking: {value: 0.045, dist: {type: "triangular", min: 0.035, mode: 0.045, max: 0.065}}
    reference_brandenburg_2023_2025: {berliner_umland: 0.032, weiterer_metropolenraum: 0.035, kreisfreie_staedte: 0.028}
    reference_bewg_188_rental: 0.035
    reference_bewg_256: {efh_zfh: 0.025, condo: 0.030, rental_le6_units: 0.040, rental_gt6_units: 0.045}
  gross_rent_multiplier:
    label_de: "Kaufpreisfaktor (Rohertragsvervielfältiger)"
    unit: "1"
    value: 20
    dist: {type: "triangular", min: 12, mode: 20, max: 30}
    sources: [Q32]
    quality: "D"
  real_estate_transfer_tax:
    label_de: "Grunderwerbsteuersätze 2026"
    unit: "1"
    as_of: "2026-10"
    sources: [Q36]
    quality: "B"
    BW: 0.050
    BY: 0.035
    BE: 0.060
    BB: 0.065
    HB: 0.055
    HH: 0.055
    HE: 0.060
    MV: 0.060
    NI: 0.050
    NW: 0.065
    RP: 0.050
    SL: 0.065
    SN: 0.055
    ST: 0.050
    SH: 0.065
    TH: 0.050
    note_de: "Bremen 5,5 % seit 01.07.2025; Rücknahmeantrag zum 01.01.2027 offen."
  cost_notary_land_registry:
    label_de: "Notar- und Grundbuchkosten (Anteil Kaufpreis)"
    unit: "1"
    value: 0.015
    dist: {type: "triangular", min: 0.011, mode: 0.015, max: 0.020}
    sources: [Q37]
    quality: "C"
  cost_broker_buyer:
    label_de: "Maklerprovision Käufer (Anteil Kaufpreis)"
    unit: "1"
    value: 0.0357
    dist: {type: "triangular", min: 0.0, mode: 0.0357, max: 0.0714}
    sources: [Q37]
    quality: "C"
  cost_broker_seller_exit:
    label_de: "Verkaufskosten bei Exit (Anteil Verkaufspreis)"
    unit: "1"
    value: 0.03
    dist: {type: "triangular", min: 0.0, mode: 0.03, max: 0.05}
    quality: "D"
  cost_due_diligence:
    label_de: "Due Diligence / Gutachten (Anteil Kaufpreis)"
    unit: "1"
    value: 0.005
    dist: {type: "triangular", min: 0.002, mode: 0.005, max: 0.010}
    quality: "D"

# ===========================================================================
vacancy:
  vacancy_rate_structural:
    label_de: "Struktureller Leerstand nach Lage-Preset"
    unit: "1"
    sources: [Q34, Q35, Q33]
    quality: "D"
    west_growth: {value: 0.015, dist: {type: "triangular", min: 0.005, mode: 0.015, max: 0.03}}
    germany_average: {value: 0.025, dist: {type: "triangular", min: 0.015, mode: 0.025, max: 0.04}}
    east_rural: {value: 0.06, dist: {type: "triangular", min: 0.03, mode: 0.06, max: 0.12}}
    shrinking: {value: 0.09, dist: {type: "triangular", min: 0.05, mode: 0.09, max: 0.15}}
    reference_cbre_empirica_2024: {germany: 0.022, west: 0.017, east_excl_berlin: 0.054, growth_regions: 0.014, shrinking_regions: 0.069}
  vacancy_initial_months_newbuild:
    label_de: "Anlaufleerstand Neubau (Monate)"
    unit: "Monate"
    value: 3
    dist: {type: "triangular", min: 0, mode: 3, max: 6}
    quality: "D"
  vacancy_fluctuation_rate:
    label_de: "Fluktuationsquote (Mieterwechsel p.a.)"
    unit: "1/a"
    value: 0.08
    dist: {type: "triangular", min: 0.05, mode: 0.08, max: 0.12}
    quality: "D"
  vacancy_months_per_turnover:
    label_de: "Leerstandsmonate je Mieterwechsel"
    unit: "Monate"
    value: 1.0
    dist: {type: "triangular", min: 0.25, mode: 1.0, max: 3.0}
    quality: "D"
  vacancy_during_retrofit_months:
    label_de: "Leerstand während Sanierung (Monate)"
    unit: "Monate"
    value: 0
    dist: {type: "triangular", min: 0, mode: 0, max: 6}
    quality: "D"
    note_de: "0 bei Sanierung im bewohnten Zustand, bis 6 bei Entmietung."
```
