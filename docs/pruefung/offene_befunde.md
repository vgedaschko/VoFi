# Offene Befunde aus der Verifikation (Stand 27.10.2026, abgebrochen zur Kostenbegrenzung)

Die folgenden Befunde haben unabhängige Prüfer gemeldet. Sie sind **noch nicht gegengeprüft** und **noch nicht behoben**.


## Persona Energieberater/Selbstnutzer

### SN-01 [major] Kreditrate im Haushaltsbericht falsch: Rate im ersten vollen Projektjahr statt Rate des Kredits (0 € bzw. nur Zinsen der tilgungsfreien Zeit)

- **Ort:** R/report-html.R:rep_html_instruments (rate_y1, Z. 860) und Ausgabe Z. 3363; Label report.html.household.loan_item
- **Beschreibung:** Der Abschnitt 'Förderung und Kredite' meldet für jeden Kredit die 'Rate im ersten vollen Jahr'. rate_y1 ist aber der Kapitaldienst im ersten vollen Betriebsjahr des PROJEKTS (2027) und nicht der Kredit. Ein Kredit, der erst 2029/2030 ausgezahlt wird, erscheint mit 0 €/Monat. Bei tilgungsfreien Anlaufjahren erscheinen nur die Zinsen. Die Familie erfährt nicht, welche Rate sie tatsächlich tragen muss. Nachgerechnet: KfW 358 10/2/10 mit 1,48 % auf 10.000 € ergibt ab 2029 eine Annuität von 110,52 €/Monat (Paketwert 1.326,22 €/a, richtig). Für den Dachkredit über 30.000 € sind es ab 2031 331,6 €/Monat. In S4 ergibt KfW 358 25/3/10 mit 2,53 % auf 70.000 € erst 147,58 €/Monat Zinsen, ab 2033 rund 349 €/Monat Annuität.
- **Erwartet:** Je Kredit die Rate nach Ende der tilgungsfreien Zeit (Annuität) bzw. die Rate im ersten vollen Jahr nach Auszahlung des Kredits, zum Beispiel 'Familie: kfw358_dach 30.000 €, Rate ab 2031 rund 330 € pro Monat (2029–2030 nur Zinsen rund 35 €)'.
- **Tatsächlich:** S4: 'kfw358_2030: Kreditbetrag rund 70.000 €, Rate im ersten vollen Jahr rund 0 € pro Monat' und 'kfw358_2033: ... rund 0 € pro Monat'. Familie: 'kfw358: ... Rate im ersten vollen Jahr rund 10 € pro Monat', 'kfw358_dach: Kreditbetrag rund 30.000 €, Rate im ersten vollen Jahr rund 0 € pro Monat'.
- **Reproduktion:** LANG=C.UTF-8 VOFI_PKG=<Checkout 8f645ec> Rscript /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/sn/repro_s4_haushalt.R  (gibt die Zeilen 'Rate im ersten vollen Jahr' des S4-Haushaltsberichts aus); Familie: repro_familie.R im selben Verzeichnis (familie.yaml).

### SN-02 [major] Amortisationsjahr im Haushaltsbericht ist praktisch immer das Stichtagsjahr ('2027 bezahlt gemacht'), weil der Zeitwert zum Bruttopreis ohne Abzug der Förderung angesetzt wird

- **Ort:** R/report-views.R:rep_household_summary (payback_year, Z. 596–613); KPI payback_vs_reference mit rv_path_basis = measures
- **Beschreibung:** Im Haushaltsmodus wird die Vermögensamortisation mit dem Komponenten-Zeitwert der Maßnahmen gerechnet. Dieser setzt die Maßnahme in t = 0 mit den vollen Bruttokosten an, ohne Abzug des Zuschusses. Damit gilt W_0 = Einlage, die Differenz zur Referenz ist 0. Ab der Zuschusszahlung in t = 1 ist sie positiv. Jede geförderte Maßnahme 'hat sich' deshalb im ersten Jahr 'bezahlt gemacht' (payback_vs_reference = 0 Jahre). Die aussagekräftige Größe ohne Restwert rechnet das Paket richtig (S4 v2: 4 Jahre bzw. 2030, entspricht dem Muster in Memo 07 'nach etwa vier bis fünf Jahren'; Familie B: 2032, Familie C: 2043). Diese Größe erscheint im Haushaltsbericht aber nicht. Zusätzlich zeigt die Tabelle 'Ihre Varianten im Vergleich' im selben Bericht 'Amortisationsjahr n. d.' für alle Varianten.
- **Erwartet:** Familie B: 'hat sich voraussichtlich 2032 bezahlt gemacht' (ohne Restwert, unabhängig nachgerechnet: Vermögensdifferenz B−A ohne Restwert 2031 −246 €, 2032 +2.604 €). S4 v2: 2030. Höchstens zusätzlich und klar gekennzeichnet die Variante mit Zeitwert. Die Tabelle stimmt mit dem Text überein.
- **Tatsächlich:** S4 v1, S4 v2, Familie B und C: 'Die Investition hat sich voraussichtlich 2027 bezahlt gemacht (Vermögensvergleich mit dem Zeitwert der Maßnahmen).' Die Tabelle zeigt 'Amortisationsjahr n. d. / n. d. / n. d.'. vofi_kpis(): payback_vs_reference = 0, payback_vs_reference_ex_rv = 4 (S4 v2) bzw. 6 (Familie B).
- **Reproduktion:** repro_s4_haushalt.R (siehe SN-01) gibt payback-Texte und payback_*-KPIs aus; Familie: cmp <- vofi_compare(vofi_read_scenario('familie.yaml')); vofi_kpis(cmp)[grepl('payback_vs', vofi_kpis(cmp)$kpi), c('variant','kpi','value')]

### SN-03 [major] 'Gesamtersparnis über 25 Jahre' widerspricht den 'Gesamtkosten' im selben Bericht (Eigenanteil und Investitionen fehlen), in S4 sogar mit umgekehrtem Vorzeichen

- **Ort:** R/report-views.R:rep_household_summary (total_saving Z. 534–539 vs. total_cost Z. 571–577)
- **Beschreibung:** total_saving summiert nur die Differenz der monatlichen Belastung. Investitionen aus Eigenmitteln (Eigenanteil) bleiben außen vor, sodass Kredit-Tilgungen zählen, Eigenmittel-Investitionen aber nicht. total_cost enthält dagegen Eigenanteil und Belastung. Der Haushalt bekommt damit zwei unvereinbare Gesamtaussagen. S4 v1: Gesamtkosten 253.500 € gegenüber 285.800 € in der Referenz, also 32.300 € weniger, der Text sagt aber '70.100 € mehr'. Differenz = Eigenanteil 172.599 − 70.101 = 102.498 €. Familie C: Text 'sparen 54.400 €', Gesamtkosten-Differenz 189.093 − 143.784 = 45.309 €.
- **Erwartet:** Gesamtersparnis = Gesamtkosten(Referenz) − Gesamtkosten(Variante) (Memo 07: 'Summe aller variantenabhängigen Auszahlungen abzüglich Zuschüsse und Erlöse'), d. h. S4 v1 'sparen rund 32.400 €', Familie C 'sparen rund 45.300 €'.
- **Tatsächlich:** S4 v1: 'Über 25 Jahre zahlen Sie gegenüber base insgesamt rund 70.100 € mehr.' neben 'Über 25 Jahre zahlen Sie insgesamt rund 253.500 €' (base 285.800 €). Familie C: 'sparen ... insgesamt rund 54.400 €'.
- **Reproduktion:** repro_s4_haushalt.R (Ausgabe der Items total_saving/total_cost je Variante)

### SN-04 [major] 'Zusätzlich sind Nachschüsse von ... nötig' zählt doppelt: Die Nachschüsse finanzieren die laufende Belastung, die schon in den Gesamtkosten steckt

- **Ort:** inst/labels/de/report.yaml household.text.equity_calls (Z. 282) und Glossar calls_def (Z. 798); R/report-views.R:rep_household_summary Z. 586–592
- **Beschreibung:** Mit dem Profil selbstnutzer (Kontokorrentlimit 0) zahlt der Haushalt die Energierechnungen zunächst aus dem Ersparten. Ist es aufgebraucht, verbucht das Modell den Rest als Nachschüsse, in allen Varianten, auch in 'Gaskessel behalten'. Die Familie zahlt diese Beträge in Wirklichkeit aus dem laufenden Einkommen. Der Bericht schreibt aber 'Zusätzlich sind Nachschüsse von insgesamt rund 145.700 € nötig', und das Glossar sagt 'Geld, das Sie später zusätzlich einzahlen müssen'. Nachgerechnet für base: Erspartes 40.000 + Habenzinsen 3.384,60 + Nachschüsse 145.708 = 189.093 € = ausgewiesene Gesamtkosten. Die Nachschüsse sind also kein zusätzliches Geld. Der Leser addiert 189.100 + 145.700 €. Die Vergleichsrechnung (Endwertdifferenz) bleibt richtig, unabhängig nachgerechnet.
- **Erwartet:** Nachschüsse als Teil der Gesamtkosten bzw. als 'aus dem laufenden Einkommen zu zahlen' kennzeichnen, ohne 'zusätzlich', und mit einem Hinweis, dass sie die laufenden Energiekosten decken. Eine Restriktion nur, wenn sie die Sparfähigkeit übersteigen.
- **Tatsächlich:** base: 'Über 25 Jahre zahlen Sie insgesamt rund 189.100 €' und 'Zusätzlich sind Nachschüsse von insgesamt rund 145.700 € nötig'. B: 111.700 € und 'zusätzlich' 69.300 €. C: 143.800 € und 'zusätzlich' 98.300 €.
- **Reproduktion:** LANG=C.UTF-8 VOFI_PKG=<Checkout> Rscript /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/sn/repro_familie.R (Items total_cost/equity_calls); Ledger base: sum(dep_interest)=3.384,60, sum(equity_call)=145.708

### SN-05 [major] 'Eigenanteil nach Förderung (Einmalbetrag)' bzw. 'zu Beginn' ist die Summe aller Investitionen über 25 Jahre abzüglich Krediten

- **Ort:** inst/labels/de/report.yaml household.text.own_contribution (Z. 280), html.household.own_contribution (Z. 782), Glossar own_def (Z. 796); KPI own_contribution
- **Beschreibung:** Die Kennzahl own_contribution summiert nach Spec 00 §12.3 die Investitionen aller Perioden nominal und zieht Zuschüsse und neue Kredite ab. Der Bericht nennt sie aber 'Einmalbetrag', und das Glossar erklärt 'Was Sie zu Beginn aus eigenen Mitteln zahlen, nachdem Zuschüsse abgezogen sind'. Dass Kredite abgezogen sind, steht dort nicht. Bei stufenweisen Varianten ist die Aussage grob falsch: S4 v2 'Eigenanteil (Einmalbetrag) rund 157.300 €' = WP 2027 32.960 + Dach 2032 47.762,09 + Anstrich 2033 14.266,54 + Fenster 2042 31.452,25 + WP-Ersatz 2047 46.507,36 − 15.680. Heute fallen nur 32.960 − 15.680 = 17.280 € an. S4 base 'Einmalbetrag 172.600 €' für Maßnahmen 2030–2050. Außerdem fehlt die Vorfinanzierung des Zuschusses: Familie B zahlt in t = 0 34.000 € aus dem Ersparten, ausgewiesen sind 14.400 €.
- **Erwartet:** Eigenanteil heute bzw. im Jahr der Maßnahme getrennt je Stufe (Konzept 1.4 'Eigenanteil heute nach Förderung'), Kredite im Text genannt, Vorfinanzierung des Zuschusses (max_financing_need) ausgewiesen.
- **Tatsächlich:** S4 v2: 'Ihr Eigenanteil nach Förderung (Einmalbetrag) beträgt rund 157.300 €.' S4 base: 'rund 172.600 €'. Glossar: '... zu Beginn ... (Einmalbetrag)'.
- **Reproduktion:** repro_s4_haushalt.R (Item own_contribution); Ledger S4 v2 capex-Zeilen je t

### SN-06 [major] Annahmentabelle des Haushaltsberichts zeigt interne Bezugsausdrücke statt Zinssätzen ('ref: market.mortgage_rate', 'Zins ref: funding.kfw358.loan.variants.v10_2_10.rate_pa')

- **Ort:** R/report-html.R:rep_html_assumptions_short (Z. 3000 ff.) mit rep_html_spec_text (Z. 1132) → rep_value_text
- **Beschreibung:** rep_html_spec_text gibt nur Konstanten als Zahl aus und schreibt sonst den Wertausdruck. Der Habenzins aus dem Profil selbstnutzer ist ein Bezug (anchor 2,5 %), ebenso der Kontokorrentzins und der Zins jedes Förderkredits aus der Bibliothek. Damit stehen in jedem Haushaltsbericht mit KfW-Kredit die wichtigsten Annahmen (Zinsen) als technischer Pfad da. Die Familie erfährt nicht, dass ihr KfW-358-Kredit 1,48 % (S4: 2,53 %) kostet.
- **Erwartet:** Habenzins 2,50 %, Sollzins Kontokorrent 6,00 % (Basisfall), Kredit kfw358 10.000 € zu 1,48 % (10/2/10), S4: 70.000 € zu 2,53 %.
- **Tatsächlich:** Familie: 'Habenzins ref: market.mortgage_rate', 'Sollzins Kontokorrent ref: market.mortgage_rate', 'v_b_wp_pv: Kredit kfw358 10.000 €, Zins ref: funding.kfw358.loan.variants.v10_2_10.rate_pa'. S4: 'Zins ref: funding.kfw358_2030.loan.variants.v25_3_10.rate_pa'.
- **Reproduktion:** repro_s4_haushalt.R bzw. repro_familie.R (grep 'ref:' im Berichtstext)

### SN-07 [major] Risiko in Worten ist ohne Aussage: 'in 8 von 10 simulierten Zukünften zwischen 410 € und 410 €', und die Zeilen nennen keine Variante

- **Ort:** R/report-views.R:rep_household_range (Z. 635 ff., KPI monthly_burden_y1); R/report-html.R Abschnitt risk (Haushalt)
- **Beschreibung:** Die Bandbreite der Belastung wird aus monthly_burden_y1 gebildet. Im ersten Jahr (2027) sind Energiepreis-Startwert, CO2-Preis (60 €/t) und Inflation fest. Bei Unsicherheit nur über Energie- und CO2-Preispfade, also dem typischen Haushaltsfall, ist q10 = q50 = q90 exakt. Die Simulation zeigt dagegen echte Bandbreiten, z. B. monthly_burden_avg10 für B 311–340 € und eine Endwertdifferenz P5–P95 von 73.874–136.534 €. Im Abschnitt 'Wie sicher ist das Ergebnis?' stehen drei solche Zeilen ohne Variantenname untereinander. Die Frage der Familie nach dem Risiko bei steigenden Gas- und CO2-Preisen beantwortet der Bericht damit nicht.
- **Erwartet:** Bandbreite einer Größe, die die Preisunsicherheit trägt (z. B. Ersparnis bzw. Belastung im Mittel der ersten 10 Jahre oder in einem späteren Jahr), mit Variantenbezug; degenerierte Spannen nicht als 'zwischen X und X' ausgeben.
- **Tatsächlich:** 'Voraussichtlich rund 410 € pro Monat; in 8 von 10 simulierten Zukünften zwischen 410 € und 410 €.' (base), zweimal '... zwischen 220 € und 220 €.' (B, C), ohne Variantenbezeichnung. MC-Statistik monthly_burden_y1: q10 = q50 = q90 = 222,9567.
- **Reproduktion:** repro_familie.R (n_sim = 200): Items range_y1 und mc$stats für monthly_burden_y1/avg10

### SN-08 [major] Reduzierte Haushaltsvorlage (Excel) für Mittler fehlt

- **Ort:** vofi_excel_template() / R (Excel-Vorlage); inst/templates
- **Beschreibung:** Konzept 5.3 und 7.1 (v1 ●) sowie die Entscheidung A8 sehen für das Betriebsmodell 'Energieberater bedient Haushalt' eine reduzierte Haushaltsvorlage vor (Projekt, Gebäude, Verbrauch, Heizung, Angebot, Haushalt). WS-A2 soll laut Konzept prüfen: 'Haushaltsvorlage ergibt mit Defaults ein gültiges Szenario'. vofi_excel_template(path, example, overwrite) kennt keinen Haushaltsmodus. Im Paket gibt es weder 'Haushaltsvorlage' noch 'reduzierte' Vorlage. Ein Energieberater muss die volle Vorlage bzw. YAML nach S4 nachbauen. Dafür sind Detailkenntnisse nötig, etwa 'add: energy.stages.<s>' statt 'set', heat_pump/self_consumption_carrier, extra_consumption für Haushaltsstrom und overdraft-Profil.
- **Erwartet:** Generierte reduzierte Haushaltsvorlage, die mit Defaults ein gültiges Selbstnutzer-Szenario ergibt.
- **Tatsächlich:** Nur die vollständige Vorlage inst/templates/vofi_eingabe.xlsx; keine Option/Funktion für die Haushaltsvorlage.
- **Reproduktion:** grep -rni 'haushaltsvorlage\|reduziert' R/ inst/  → keine Treffer; args(vofi_excel_template) → (path, example = NULL, overwrite = FALSE)

### SN-09 [minor] Kopfsatz 'Sie erhalten Förderung von insgesamt rund ... €' und Ampel gelten nur für die beste Variante, ohne sie zu nennen

- **Ort:** R/report-html.R:rep_html_summary_household (Z. 1389–1420)
- **Beschreibung:** Im Abschnitt 'Das Wichtigste in Kürze' stehen Ampel und Förderbetrag ohne Variantenbezug unter den Variantenblöcken. Der Förderbetrag ist der der bestplatzierten Variante. Familie: 19.600 € (B), Variante C erhält aber 19.600 + 7.605,20 = 27.205 €. S4: 35.800 € (v1), v2 erhält 15.680 €.
- **Erwartet:** Förderung je Variante bzw. mit Variantennamen ('Variante B: 19.600 €, Variante C: 27.200 €').
- **Tatsächlich:** 'Sie erhalten Förderung von insgesamt rund 19.600 €.' (Familie), 'rund 35.800 €' (S4), ohne Varianten.
- **Reproduktion:** repro_familie.R / repro_s4_haushalt.R (grep 'Sie erhalten Förderung')

### SN-10 [minor] Haushaltsbericht verwendet interne Kennungen statt Bezeichnungen (Varianten, Maßnahmen, Programme, Treiber)

- **Ort:** R/report-html.R (rep_html_var_heading, rep_html_grants, rep_html_drivers_text), R/report-views.R (ref_label = Varianten-id)
- **Beschreibung:** Die vergebenen Variantenlabels (z. B. 'B Wärmepumpe 2027 mit PV 8 kWp (KfW 458)') erscheinen nirgends. Texte lauten 'Gegenüber base sparen Sie ...', Überschriften 'Variante v_b_wp_pv'. Zuschüsse heißen 'Investitionszuschuss wp (458)' bzw. 'dach (beg_em_huelle)', Kredite 'kfw358'. Die Treiber heißen 'energy_price_gas.growth', 'energy_price_power.growth', 'inflation.mu'. Der Satzbaustein-Aufbau des Zuschusses (30 % + 16 % + 30 %, gedeckelt auf 70 % von 28.000 €) wird nicht gezeigt.
- **Erwartet:** Bezeichnungen aus variants.<v>.label, measures.<m>.label, Programmbezeichnung der Bibliothek und Labels der Overlay-Einträge; optional Fördersatzaufbau.
- **Tatsächlich:** 'Gegenüber base sparen Sie im ersten vollen Nutzungsjahr rund 190 € pro Monat.'; 'Am stärksten hängt das Ergebnis von Wachstum Gasnetzentgelte p. a., energy_price_gas.growth und Faktor Biomethan-Mehrkosten ab.'
- **Reproduktion:** repro_familie.R (Berichtstext)

### SN-11 [minor] Spalte 'Wartung' ist immer 0, obwohl Wartung und Schornsteinfeger anfallen (unter 'Energie' gebucht)

- **Ort:** R/report-views.R (Zuordnung Kategorie maintenance) / Energieexpander: Zeile '<seg>__service' mit Kategorie energy_cost
- **Beschreibung:** service_eur_pa (Wartung der Wärmeerzeugung, Schornsteinfeger) wird als Zeile 'Wartung und Messdienst' mit Kategorie energy_cost gebucht und landet in der Spalte 'Energie'. Die Spalte 'Wartung' der Haushaltstabelle zeigt deshalb 0, obwohl Gas 300 €/a brutto (25 €/Monat) und WP 250 €/a brutto anfallen. Die Spalte 'Energie' ist zudem um die PV-Erlöse gekürzt, ohne dass das in der Spalte erkennbar ist.
- **Erwartet:** Wartung in der Spalte 'Wartung' ausweisen (Memo 07 §5.4: 'Wartung/Schornsteinfeger').
- **Tatsächlich:** Familie base 2027: Energie 410, Wartung 0; vofi_household_view(): maintenance = 0 in allen Jahren.
- **Reproduktion:** hv <- vofi_household_view(vofi_run(vofi_build(vofi_read_scenario('familie.yaml'), variant='v_b_wp_pv'))); hv[1:3, c('year','energy','maintenance')]

### SN-12 [minor] Deterministische und simulierte Werte gemischt ohne Kennzeichnung

- **Ort:** R/report-html.R:rep_html_variants_household vs. rep_household_summary
- **Beschreibung:** Bei einem MC-Vergleich stehen im selben Haushaltsbericht deterministische Kopftexte und MC-Mittelwerte in der Vergleichstabelle nebeneinander, ohne Hinweis. Beispiel base: Text 'Nachschüsse rund 145.700 €' gegen Tabelle 'Summe der Nachschüsse 152.900 €'. Text 'höchstens rund 9 % Ihres Nettoeinkommens' gegen Tabelle 'Belastungsquote (Maximum) 11 %'.
- **Erwartet:** Einheitliche Basis oder Kennzeichnung 'Basisfall' bzw. 'Mittel der Simulation'.
- **Tatsächlich:** siehe Beschreibung (Familie, n_sim = 1000)
- **Reproduktion:** cmp <- vofi_compare(vofi_read_scenario('familie.yaml'), n_sim = 1000, seed = 4711); vofi_report(cmp, 'b.html', mode = 'household')

### SN-13 [minor] README veraltet und für Mittler irreführend

- **Ort:** README.md
- **Beschreibung:** Laut README sind Simulation, Vergleich, Sensitivität und Berichte noch Platzhalter, die vofi_error_not_implemented melden. Bei 8f645ec stimmt das nicht. Es fehlen Hinweise auf vofi_example() (S1–S5), den Haushaltsmodus und den typischen Arbeitsablauf (vofi_compare → vofi_report(mode = 'household')). Vignetten gibt es nicht.
- **Erwartet:** Aktueller Status und ein Einstieg für Haushaltsfälle (z. B. S4).
- **Tatsächlich:** 'Status: in Entwicklung (Phase 0 ...). ... Simulation, Vergleich, Sensitivität und Berichte sind noch Platzhalter und melden vofi_error_not_implemented.'
- **Reproduktion:** cat README.md

### SN-14 [minor] Keine umschaltbare Sicht 'in heutiger Kaufkraft' im Haushaltsbericht

- **Ort:** vofi_report() / R/report-html.R
- **Beschreibung:** Konzept 1.4 und Memo 07 §5.4 Nr. 6 verlangen für den Haushaltsmodus nominale Werte mit umschaltbarer Kaufkraftsicht. vofi_report() hat dafür kein Argument, und die Vorlage keinen Schalter. Der Bericht vermerkt nur 'die Beträge sind nominal'. Über 25 Jahre wirkt das stark: Die Belastung steigt von 410 auf 780 €/Monat, bei rund 75 % Preissteigerung.
- **Erwartet:** Option bzw. Spalte in heutiger Kaufkraft (Division durch VPI-Index).
- **Tatsächlich:** Nur nominale Ausgabe; grep 'Kaufkraft' in R/ und Labels ohne Treffer.
- **Reproduktion:** args(vofi_report); grep -rni kaufkraft R/ inst/labels


## Persona Energieberater/Selbstnutzer

### PC-01 [major] Warmmieten-Kennzahlen (_y1) und Restriktion Warmmiete messen bei construction_months = 0 das Baujahr vor Umlagebeginn, nicht das erste Jahr nach der Sanierung

- **Ort:** R/kpi-realestate.R (warm_rent_y1, warm_rent_change_prepost_y1, warm_rent_change_y1, restriction_warm_rent); Szenario-Muster aus inst/extdata/examples/s1_wu_mfh_1963_eh70.yaml
- **Beschreibung:** Das erste volle Betriebsjahr wird allein aus dem Zeitraster bestimmt. Mit grid.construction_months = 0 (so im Referenzszenario S1, das der Controller als Vorlage nimmt) und completion_date 2027-10-01 ist 2027 das Jahr y1. Die Umlage beginnt aber erst 2028, und die Heizkosten der Mieter sinken nur im 4. Quartal. Die Folge: Die Warmmietenänderung gegenüber der Referenz wird als Senkung um 0,20 EUR/m² ausgewiesen, tatsächlich steigt sie im ersten Jahr nach der Sanierung um 1,33 EUR/m². Die Restriktion Warmmiete (Schwelle 0,50) ist 0 statt 1, P(besser) für die Warmmiete steht bei 100 %, und die Ampel zeigt kein K.-o.-Kennzeichen. Die Gremienvorlage verschweigt damit den Warmmietenanstieg. Auch S1 ist betroffen: warm_rent_change_y1 = −0,20, tatsächlich +0,31 EUR/m² im Jahr 2028 trotz Beschluss 'warmmietenneutral'. Mit construction_months = 9 stimmen die Werte (0,94 / 1,33 / Restriktion 1, K.-o. in der Ampel), das steht aber nirgends dokumentiert, und das Paket warnt nicht, wenn die Fertigstellung einer Maßnahme mit Umlage innerhalb von y1 liegt.
- **Erwartet:** y1-Kennzahlen bzw. Restriktion beziehen sich auf das erste volle Jahr nach Fertigstellung bzw. Umlagebeginn (eigenes Beispiel: change_prepost 0,94, change_vs_reference 1,33, restriction_warm_rent = 1, Ampel mit K.-o. Warmmiete); mindestens eine Warnung, wenn completion_date bzw. Umlagebeginn nach dem Beginn von y1 liegt
- **Tatsächlich:** warm_rent_change_prepost_y1 = −0,250, warm_rent_change_y1 = −0,199, restriction_warm_rent = 0, Ampel 'gelb (nur Basisfall)' ohne K.-o.; S1: warm_rent_change_y1 = −0,203 statt +0,308
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/ctrl/repro/repro_all.R Abschnitt F1 (LANG=C.UTF-8 PKG=<checkout 8f645ec> Rscript repro_all.R); YAML: /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/ctrl/repro/mfh1972_c0.yaml. Kern: k <- vofi_kpis(vofi_compare(vofi_read_scenario('mfh1972_c0.yaml'))); k[k$kpi %in% c('warm_rent_change_y1','restriction_warm_rent'),]; vofi_tenant_view(...) Jahr 2028: change_vs_reference 1,333

### PC-02 [major] Variantenoperation set auf Katalogfelder der Wohnungsgruppe (voluntary_cap_per_m2, extra_loss_share) scheitert, wenn das Feld nicht in der Basis steht

- **Ort:** R/scenario-variants.R:var_path_known / var_template_fields
- **Beschreibung:** Nach R-112 gilt ein set-Pfad als vorhanden, wenn das Elternelement existiert und das Blatt ein Feld der Feldtabellen von Spec 01 ist. var_template_fields('unit_groups.<g>.rent_law') liefert aber nur modernization_levy, voluntary_cap_mode, hardship_share, interest_subsidy_in_559e und kuerzung_558_5. voluntary_cap_per_m2 (01b Z. 317) fehlt, auf Gruppenebene fehlen extra_loss_share (01b Z. 293), rent_eur_m2_month, growth_from und weitere. Zwei typische Controller-Fälle brechen deshalb mit 'Pfad existiert nicht' ab, obwohl S1 genau diesen Pfad verwendet: die freiwillige bzw. warmmietenneutrale Umlagekappe nur in der Sanierungsvariante und die Mietminderung nur in der Bauvariante. Das geht nur, wenn die Basis das Feld zufällig explizit als null bzw. 0 führt. Die Fehlermeldung lässt nicht erkennen, wie man das Problem behebt.
- **Erwartet:** set: {unit_groups.bestand.rent_law.voluntary_cap_per_m2: 1.10} bzw. {unit_groups.bestand.extra_loss_share: …} wird angewandt (R-112)
- **Tatsächlich:** vofi_error_validation 'Operation set: der Pfad 'unit_groups.bestand.rent_law.voluntary_cap_per_m2' existiert nicht …'
- **Reproduktion:** txt <- readLines(vofi_example('s1_wu_mfh_1963_eh70')); f <- tempfile(fileext='.yaml'); writeLines(txt[!grepl('voluntary_cap_per_m2: null', txt)], f); vofi_resolve(vofi_read_scenario(f), variant='v2_eh70')  # Fehler. Analog: in mfh1972_c9.yaml unter variants.v2_eh85.set 'unit_groups.bestand.extra_loss_share: {series: {2027: 0.05, 2028: 0}, fill: locf, before: first}' ergänzen -> derselbe Fehler

### PC-03 [major] Ein neuer Fall ist ohne Entwicklerspezifikation praktisch nicht anlegbar: README veraltet, keine Anwenderdoku zu den Szenariofeldern, irreführende Fehler

- **Ort:** README.md; man/vofi_read_scenario.Rd, vofi_scenario.Rd; docs/Konzept.md; Bibliothekseintrag prices/referenzszenarien_2026
- **Beschreibung:** Das README meldet 'Simulation, Vergleich, Sensitivität und Berichte sind noch Platzhalter und melden vofi_error_not_implemented'. Das ist falsch, alle Funktionen laufen. Weder Hilfeseiten noch Konzept beschreiben die Szenariofelder. Wer einen neuen Fall anlegen will, muss S1 kopieren und Bedeutungen raten, etwa: demand_kwh ist Nutzwärme, amount_eur enthält die Baubegleitung, facts.ee_class ist Pflicht, loan_variant-Codes, und construction_months steuert die y1-Kennzahlen (PC-01). Das geht nur mit der Entwicklerspezifikation (über 17.000 Zeilen). Die Excel-Vorlage hilft mit Bezeichnungen, erklärt aber zum Beispiel 'Wärmebedarf kWh/Jahr' nicht als Nutzwärme. Typische Falle beim ersten Versuch: market: {from: prices/referenzszenarien_2026, use: market} (wie in S1) ohne den zugehörigen shared-Block bricht mit 'der Pfad shared.bio_premium_factor existiert nicht (Zeile 1, Spalte 32)' ab. Die Zeilenangabe bezieht sich auf den Ausdruck, nicht auf die Datei, und einen Lösungshinweis gibt es nicht. Zusätzlich überdecken je Variante und Aufruf rund 60 Meldungen 'Korrelationspaar … verworfen' (bei Standardprozessen aus der Bibliothek) die relevanten Hinweise.
- **Erwartet:** Aktuelles README mit Kurzanleitung 'neuen Fall anlegen'; Feldbeschreibungen in Hilfe bzw. Vignette; Fehlermeldung mit Lösung (shared-Block derselben Quelle einbinden); verworfene Bibliotheks-Korrelationen zusammengefasst in einer Meldung
- **Tatsächlich:** veraltetes README, keine Felddoku, Abbruch mit unverständlicher Meldung, Meldungsflut
- **Reproduktion:** cat(readLines(file.path(PKG,'README.md'))[1:12], sep='\n'); # Falle: in mfh1972_c0.yaml 'market:\n  from: prices/referenzszenarien_2026\n  use: market' ergänzen -> vofi_compare() bricht ab: 'Ausdruck market.bio_fuel_premium_base * shared.bio_premium_factor: der Pfad shared.bio_premium_factor existiert nicht'; Meldungsflut: Rscript -e "devtools::load_all(PKG); vofi_compare(vofi_read_scenario(vofi_example('s1_wu_mfh_1963_eh70')))" 2>&1 | grep -c Korrelationspaar  # 120

### PC-04 [minor] Kennzahlen in EUR/m²/Monat werden in print(<vofi_comparison>) und in Bericht und Kurzvorlage auf ganze Euro gerundet

- **Ort:** R/methods-compare.R:87,108 (rep_fmt_value(..., 0)); Berichtstabellen R/report-html.R
- **Beschreibung:** print.vofi_comparison formatiert alle Kennzahlen mit digits = 0, auch Einheiten wie EUR_m2_month. Warmmiete 10,28 erscheint als '10 EUR/m²/Monat', Warmmietenänderungen von −0,20 bzw. 0,94 als '0' bzw. '1 EUR/m²/Monat'. In der Gremienvorlage stehen deshalb für dieselbe Größe drei Werte: '0,94 €/m²' (Restriktion), '0,93 EUR/m²/Monat' (Summary) und '1 EUR/m²/Monat' (Kennzahltabelle). Gegen die Schwelle 0,50 ist eine Ganzzahl-Anzeige unbrauchbar.
- **Erwartet:** zwei Nachkommastellen für EUR/m²/Monat (z. B. 10,28 / 0,94 / 1,33)
- **Tatsächlich:** '10 EUR/m²/Monat', '0 EUR/m²/Monat', '1 EUR/m²/Monat'
- **Reproduktion:** print(vofi_compare(vofi_read_scenario('/tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/ctrl/repro/mfh1972_c9.yaml')))  # Zeilen Warmmiete/Warmmietenänderung; ebenso vofi_report(..., template='kurzvorlage')

### PC-05 [minor] Abschnitt Energie und CO2 des Berichts zeigt im Variantenvergleich nur die Referenz

- **Ort:** R/report-html.R:rep_html_sec_energy (verwendet nur rc$res)
- **Beschreibung:** Im Vergleich stehen Energie- und CO2-Kosten des Vermieters (erstes Jahr bzw. Summe) und CO2-Emissionen nur für die Referenz base (−447.637 € bzw. −119.494 €). Für v2_eh85 erscheint nur die CO2-Minderung. Die Vermieterkosten der Variante (13.076 € bzw. 1.553 €) und die CO2-Vermeidungskosten fehlen. Gerade die CO2- und § 5a-Kostenaufteilung (50/50 bei neuer Gasheizung ab 2028, Bio-Mehrkosten ab 2029) ist hier ein wesentlicher Entscheidungstreiber, sie ist im Bericht aber nicht nachvollziehbar.
- **Erwartet:** Energie-, CO2- und § 5a-Kosten sowie Emissionen je Variante (und Differenz), dazu CO2-Vermeidungskosten
- **Tatsächlich:** nur Referenzzeilen; v2 nur 'CO₂-Minderung 1.551,6 t'
- **Reproduktion:** repro_all.R Abschnitt F4: vofi_report(vofi_compare(sc9), 'b.html'); Text nach 'Energie- und CO2-Kosten aus dem Zahlungsbuch' enthält nur base-Werte

### PC-06 [minor] THG-Bilanz ignoriert den Bio-Anteil der neuen Gasheizung, der Strom-Emissionsfaktor bleibt 30 Jahre konstant bei 560 g/kWh, und der in Spec 01b verlangte Hinweis fehlt

- **Ort:** R/type-flow-energy-cost.R (Zeile 'emission' = kWh * ghg / 1000 ohne (1 − beta)); fehlende Info-Meldung
- **Beschreibung:** Die CO2-Kosten rechnen mit dem fossilen Anteil der Bio-Treppe (2040: 40 % fossil, der CO2-Vermieteranteil sinkt entsprechend). Die Memo-Zeile co2_emission der Gasheizung bleibt aber 2028 bis 2056 konstant bei 88,51 t/a, obwohl ab 2040 60 % Biomethan eingesetzt werden (Anlage 9: Biogas 140 statt 240 g/kWh). Die Wärmepumpe wird über 30 Jahre mit 560 g/kWh bilanziert. Spec 01b §3.2.1 (ghg_factor_kg_kwh) verlangt hier den Hinweis 'Strom konstant – abnehmender Strommix als Pfad empfohlen', der fehlt (es gibt kein Label). CO2-Minderung (1.551,6 t) und CO2-Vermeidungskosten, also das CO2-Pfad-Kriterium der Persona, sind damit verzerrt. Mit einem Strompfad (0,38 / 0,15 / 0,03 kg/kWh in 2027/2035/2045) fallen die Emissionen von V2 von 1.113,8 t auf 283,5 t.
- **Erwartet:** THG der Gasheizung mit (1 − Bio-Anteil) × fossiler Faktor + Bio-Anteil × Biogasfaktor; Info-Meldung bei konstantem Stromfaktor
- **Tatsächlich:** e_after_gas_mfh_cost__emission 2028/2040/2056 = 88,513 t; keine Meldung
- **Reproduktion:** repro_all.R Abschnitt F5: L <- vofi_ledger(vofi_compare(sc9), format='wide'); L[L$variant=='base' & L$category=='co2_emission', c('key','2028','2040','2056')]  # konstant 88,513; dagegen co2_landlord 2028 −2.592, 2040 −2.938 (bio-bereinigt)

### PC-07 [minor] Gremienvorlage: interner Parameterschlüssel statt Bezeichnung, Varianten-ids statt Labels, Tilgungszuschuss als Mittelherkunft doppelt gezählt

- **Ort:** R/report-html.R (Kurzvorlage: 'Die wichtigsten Risiken', Mittelherkunft, Variantenbezeichnung)
- **Beschreibung:** (1) Unter 'Die wichtigsten Risiken' steht '2. inflation.mu', also ein roher Prozessparameterschlüssel ohne Label. Dasselbe im Satz 'Das Ergebnis hängt vor allem von Mietsteigerung, inflation.mu und Liegenschaftszins ab'. (2) Die Vorlage benennt die Varianten durchgehend mit ihren ids ('v2_eh85', 'base'). Das Label 'V2 Sanierung EH 85 EE (KfW 261)' erscheint nirgends (grep 0 Treffer in Bericht und Kurzvorlage). (3) In der Mittelherkunft steht der Tilgungszuschuss von 20.000 € als 'Zuschüsse' neben dem vollen KfW-Darlehen von 1.365.000 €. Er ist aber keine Mittelherkunft zum Investitionszeitpunkt, sondern mindert später die Restschuld. Die Summe der Mittelherkunft übersteigt die Investition deshalb auch ohne Überfinanzierung.
- **Erwartet:** Bezeichnungen (z. B. 'Inflationsrate: Mittelwert'), Variantenlabels, Tilgungszuschuss als Vermerk zum Darlehen
- **Tatsächlich:** 'inflation.mu', 'v2_eh85', Mittelherkunft: Zuschüsse 20.000 € zusätzlich zu kfw261 1.365.000 €
- **Reproduktion:** cmp <- vofi_compare(vofi_read_scenario('/tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/ctrl/repro/mfh1972_c9.yaml'), n_sim = 400, seed = 1); f <- vofi_report(cmp, file.path(tempdir(),'g.html'), template='kurzvorlage', open=FALSE); grep('inflation.mu', readLines(f), value=TRUE); sum(grepl('V2 Sanierung EH 85', readLines(f)))  # 0

### PC-08 [minor] Förderbarwert wird als 'inkl. Zinsvorteile' beschriftet, enthält sie aber nicht

- **Ort:** inst/labels/de/report.yaml:550 (report.html … pv_subsidies)
- **Beschreibung:** Der Bericht schreibt 'Barwert der Förderung (Zuschüsse, Tilgungs- und Zinsvorteile): 18.670 €'. Der Wert ist nach Spec nur der Barwert des Tilgungszuschusses (20.000 / 1,035² = 18.670), ohne Zinsverbilligung. Der Zinsvorteil des KfW-Kredits (0,45 Pp auf 1,365 Mio. über 10 Jahre, rund 6.100 €/a) ist nicht enthalten. Ein Leser hält den Förderwert damit für vollständig.
- **Erwartet:** Beschriftung 'Zuschüsse und Tilgungszuschüsse (ohne Zinsverbilligung)' oder Zinsvorteil einrechnen
- **Tatsächlich:** Label behauptet Zinsvorteile, Wert ohne Zinsvorteile
- **Reproduktion:** vofi_kpis(vofi_compare(sc9))$value[...kpi=='pv_subsidies' & variant=='v2_eh85'] = 18670,21; Bericht Abschnitt 5.2.3 Text 'Barwert der Förderung (Zuschüsse, Tilgungs- und Zinsvorteile): 18.670 €'

### PC-09 [minor] Amortisationsdauer im Bestand ohne Warnvermerk ('0,0 Jahre'), Amortisation gegenüber der Referenz mit Restwertpfad 1 Jahr

- **Ort:** R/methods-compare.R / Bericht Kennzahlentabellen (payback_time, payback_vs_reference)
- **Beschreibung:** Bei Bestandsprojekten sind ΔEW und payback_time gegenüber der Unterlassung laut Spec 12.3a 'nicht als Vorteilhaftigkeit lesbar'. Die Endwertdifferenz trägt den Vermerk '*', die Amortisationsdauer erscheint aber ohne Vermerk als '0,0 Jahre' für Referenz und Variante. Dazu kommt 'Amortisation gegenüber der Referenz 1,0 Jahre' (P5 bis P95 jeweils 1,0) für eine Mehrinvestition von 1,134 Mio. €. Der Restwertpfad (Ertragswert mit Umlage und RND) springt schon in t = 1. Einem Gremium ist der Wert ohne Erläuterung nicht vermittelbar.
- **Erwartet:** Vermerk wie bei ΔEW bzw. Ausweis nur ohne Restwert; Erläuterung 'Vermögensamortisation mit Restwertpfad'
- **Tatsächlich:** 'Amortisationsdauer 0,0 Jahre' ohne Vermerk; 'Amortisation gegenüber der Referenz 1,0 Jahre'
- **Reproduktion:** print(vofi_compare(vofi_read_scenario('/tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/ctrl/repro/mfh1972_c9.yaml')))

### PC-10 [minor] Wegfall der Förderung (fehlende EE-Klasse, Set foerderstopp) ersetzt 1,3 Mio. € stumm durch unbegrenzten Kontokorrent, vofi_validate meldet nichts, DSCR 'n. d.'

- **Ort:** vofi_validate (keine Meldung expand.funding.not_eligible); Profil wu_kommunal overdraft_limit .inf
- **Beschreibung:** Mit facts: {ee_class: false} meldet vofi_validate '0 Fehler, 1 Warnung' (nur die Liquiditätswarnung). Die Nichtberechtigung erscheint erst als R-Warnung beim Build. Der KfW-Kredit entfällt, die 1.325.000 € laufen über den Kontokorrent (minimale Nettoliquidität −1.325.000 €). Der DSCR steht dann auf 'n. d.', obwohl 1,3 Mio. € Fremdkapital offen sind. Wegen des unendlichen Limits gibt es keine Liquiditätsrestriktion. Die Endwertdifferenz sinkt nur um 0,2 Mio. €. Für eine Gremienvorlage ist das irreführend.
- **Erwartet:** Validierungswarnung 'Förderung nicht berechtigt'; DSCR bzw. Kapitaldienst inklusive Kontokorrent oder Hinweis auf fehlende Anschlussfinanzierung
- **Tatsächlich:** keine Validierungsmeldung; DSCR n. d.; Kontokorrent −1,3 Mio. ohne Restriktion
- **Reproduktion:** sed 's/facts: {ee_class: true}/facts: {ee_class: false}/' mfh1972_c9.yaml > noee.yaml; vofi_validate(vofi_read_scenario('noee.yaml'), variant='v2_eh85')  # keine Förder-Meldung; vofi_compare(sc9, scenario_sets='foerderstopp') -> v2_eh85@foerderstopp: DSCR n. d., min. Nettoliquidität −1.325.000 €

### PC-11 [minor] Restwert: Modernisierungspunkte altern nicht (Anlage 2), RND am Horizont 41 Jahre bei Gebäudealter 85, Restwert dominiert

- **Ort:** global.yaml residual_value.income_value.points_decay_years: null (Spec 01a OP-09)
- **Beschreibung:** Mit der Vorgabe remaining_life_method: anlage2 zählen die 12 Punkte der Maßnahmen von 2027 im Jahr 2057 voll. RND = 0,364·85²/80 − 0,808·85 + 0,9622·80 = 41,2 Jahre für ein dann 85 Jahre altes Gebäude mit 30 Jahre alter Dämmung (ND 40) und WP (ND 20, kein Ersatz). Das ergibt einen Restwert von 7,06 Mio. € (V2) gegenüber 3,38 Mio. € (Referenz) und eine ΔEW mit Restwert von 4,85 Mio. € gegenüber 1,27 Mio. € ohne Restwert. ImmoWertV Anlage 2 sieht für länger zurückliegende Modernisierungen geringere Punkte vor. Die ungeminderte Vorgabe ohne Warnung überzeichnet die Restwertdominanz.
- **Erwartet:** Alterung bzw. Abschmelzen der Punkte als Vorgabe oder mindestens Warnung, wenn Punkte älter als ca. 20 Jahre am Horizont voll zählen
- **Tatsächlich:** keine Alterung, keine Meldung; RND 41 Jahre
- **Reproduktion:** in mfh1972_c9.yaml remaining_life_method: anlage2 setzen und remaining_life_years entfernen (Basis und Variante) -> Ledger rv_value__value 2056: base 3.375.365, v2_eh85 7.057.757; delta_vs_reference 4.845.340 vs. ex_rv 1.273.419

### PC-12 [minor] Hinweis zu excludes_explicit_replacements zählt die Sanierungsinvestition selbst als 'explizite Erneuerungen' (20,06 EUR/m²·a)

- **Ort:** R/validate-plausibility.R:1225-1237
- **Beschreibung:** Der Kennwert summiert cost_eur aller Maßnahmen mit classification 'erhaltung' (steuerliche Einordnung). In V2 sind das WDVS, Dach, Fenster und WP mit zusammen 1.625.000 € / (30 × 2.700) = 20,06 €/m²·a. Gemeint sind laut Spec die expliziten Ersatz- und Instandsetzungsereignisse im Horizont. Die Frage 'Ist der Satz um sie gemindert?' legt nahe, die Instandhaltungspauschale (15 €/m²) um 20 € zu kürzen, was offensichtlich falsch wäre.
- **Erwartet:** nur Ersatzereignisse bzw. Instandsetzungsmaßnahmen (in V2 hier 0)
- **Tatsächlich:** 'die expliziten Erneuerungen im Horizont entsprechen 20.06173 EUR/m² und Jahr' (Basis: 6,06)
- **Reproduktion:** vofi_validate(vofi_read_scenario('/tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/ctrl/repro/mfh1972_c0.yaml'))  # Hinweis [Varianten: v2_eh85] 20.06173

### PC-13 [minor] Tornado-Basiswert weicht vom deterministischen Basisfall ab, sobald der Inflationsprozess Designspalte ist

- **Ort:** R/sensitivity.R / smp_design (Zeile 1 = Basisfall)
- **Beschreibung:** Die Primärkennzahl im Basisfall ist 4.074.102 €. Ein Tornado mit params = c('rent_growth','cap_rate_rv') oder 'mortgage_rate' zeigt den Basiswert 4.074.102 €. Mit 'inflation' (bzw. bei params = NULL) zeigt er 4.075.686 €. Nach Spec 11.11 ist Zeile 1 der Basisfall. Das Set 'vorsichtig' und die Gremienvorlage bauen auf diesem Tornado auf.
- **Erwartet:** Basiswert 4.074.102 € unabhängig von der Parameterauswahl
- **Tatsächlich:** 4.075.686 € (+1.584 €) mit Inflationsprozess
- **Reproduktion:** repro_all.R Abschnitt F6: vofi_sensitivity(sc9, variant='v2_eh85', params='inflation')  # Basiswert 4.075.686; mit params=c('rent_growth','cap_rate_rv') 4.074.102


## Mietrecht/Energie/CO2

### MRE-01 [major] Warmmieten-Kennzahlen *_y1 werten im Bestand das Baujahr aus, also bevor die Umlage wirkt: Kennzahl, K.-o.-Restriktion, Ampel, Vergleich und Zielwertsuche falsch

- **Ort:** R/kpi-realestate.R: kpi_series_y1(), kpi_calc_warm_rent_change_prepost_y1(), kpi_calc_restriction_warm_rent(); R/kpi-core.R: warm_rent_change_y1; R/compare.R: Restriktion warm_rent; R/solve.R (Anwendungsfall 'warmmietenneutrale Umlage')
- **Beschreibung:** `_y1` ist das erste volle Betriebsjahr (kpi_op_years: op_year_full). Im Bestand mit construction_months 0 ist das das Bewertungsjahr 2027. In S1 und S3 wird die Maßnahme am 01.10.2027 fertig, die Umlage wirkt erst ab 01.01.2028 (§ 559b Abs. 2). Ausgewertet wird also das Jahr mit 9 Monaten Gas, 3 Monaten Wärmepumpe und ohne Umlage. Die Kennzahl misst damit keine Änderung 'vorher/nachher', und das in S1 gesetzte analysis.stabilization_year 2028 bleibt unberücksichtigt. Folgen: (1) Die SEED-Frage ist mit 'beides' zu beantworten. Der Wert −0,2382 ist für 2027 richtig gerechnet (geprüft: 27.824,30 gegen 32.397,57 EUR/a auf 1.600 m²; Stufenmodell 2027 bei 23,76 kg/m²·a gleich 30 %), aber 2027 ist das falsche Jahr. Dazu kommt Befund MRE-02 (Anzeige mit 0 Nachkommastellen). (2) Plausibel ist −0,24 nach EH 70 mit Umlage nicht. Im ersten vollen Jahr mit Umlage (2028) gilt: Umlage 1,10 + Heizkosten 0,6919 − Heizkosten vorher 1,7418 = +0,050 EUR/m²·Monat, von Hand nachgerechnet. Der Beschluss 1,10 liegt also knapp über warmmietenneutral; neutral wären 1,0499, wie der Modus warm_rent_neutral auch ergibt. (3) restriction_warm_rent prüft 2027 und schlägt deshalb bei Bestandssanierungen mit Fertigstellung im ersten Jahr nie an. Ohne Beschluss (Umlage 2,00) steigt die Warmmiete 2028 um +0,95 > Schwelle 0,50, die Kennzahl meldet aber 0; Ampel und Restriktionstabelle zeigen 'nein'. (4) warm_rent_change_y1 (V2 − Referenz) = −0,20 mit P(besser) 100 %, und der Bericht schreibt '−0,20 € je m² und Monat'. Tatsächlich ist die Warmmiete in V2 von 2028 bis etwa 2033 um 0,24 bis 0,31 EUR/m² höher als in V1 (laut vofi_tenant_view: 2028 +0,308, 2030 +0,236). (5) Die Zielwertsuche nach Spec 00 §12.8 bzw. 01b 1.9.5 (kpi = warm_rent_change_prepost_y1, target 0, param voluntary_cap_per_m2) liefert NA, weil die Kennzahl in 2027 nicht vom Parameter abhängt. Der Fehler liegt schon in der Spec: Spec 00 §12.2 definiert _y1 als erstes volles Betriebsjahr, 01b 1.9.5 und RP-14 meinen aber die Bezugsperiode j* (erste volle Periode ab Wirksamkeit der Umlage). Vermutlich gleiche Ursache, nicht im Einzelnen geprüft: monthly_burden_y1 und monthly_saving_y1 im Selbstnutzer-Bestand.
- **Erwartet:** S1 V2 (j* = 2028): warm_rent_change_prepost_y1 = +0,0501; warm_rent_y1 = 10,644; warm_rent_change_y1 = +0,308. Ohne Beschluss: +0,950 und restriction_warm_rent = 1. vofi_solve ≈ 1,0499 EUR/m²
- **Tatsächlich:** S1 V2: warm_rent_change_prepost_y1 = −0,2382; warm_rent_y1 = 10,2317; warm_rent_change_y1 = −0,2027 (P(besser) 100 %). Ohne Beschluss: −0,2382 und restriction_warm_rent = 0. vofi_solve: NA ('Kein kritischer Wert im Intervall'). S3 V2: y1 = −0,145 aus 2027 statt −0,300 aus 2028
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/me/repro/r1_y1_warmmiete.R

### MRE-02 [major] EUR/m²/Monat wird in print.vofi_comparison, print.vofi_mc und den HTML-Kennzahlentabellen mit 0 Nachkommastellen angezeigt

- **Ort:** R/methods-compare.R:87 und :108, R/methods-mc.R:84 (rep_fmt_value(..., 0)); R/report-html.R:1635 (rep_fmt_kpi(..., 0)); R/methods-misc.R rep_fmt_value(), Default-Zweig für EUR_m2_month
- **Beschreibung:** rep_fmt_value() hat für EUR_m2_month (ebenso EUR_m2 und EUR_kwh) keinen eigenen Zweig und nimmt die übergebenen digits. Vergleich, MC-Ausgabe und HTML-Kennzahlentabellen übergeben 0. Kennzahlen um ±1 EUR/m² werden dadurch zu '0 EUR/m²/Monat', Warmmieten 10,43 und 10,23 zu '10'. Im selben HTML-Bericht nennt der Fließtext −0,24 (fmt_eur(w, 2)), die Tabelle 0. In der MC-Ausgabe stehen Mittel, SE und alle Quantile auf '0 EUR/m²/Monat', während P(< 0) 100 % zeigt. print.vofi_result (digits 2) und der Excel-Export (Format #,##0.00) sind richtig.
- **Erwartet:** −0,24 EUR/m²/Monat bzw. 10,43 und 10,23 EUR/m²/Monat (mindestens 2 Nachkommastellen für EUR/m²/Monat)
- **Tatsächlich:** '0 EUR/m²/Monat' (Warmmietenänderung, beide Varianten und alle MC-Quantile), '10 EUR/m²/Monat' (Warmmiete), Warmmietenänderung gegenüber der Referenz '0 EUR/m²/Monat'
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/me/repro/r2_format.R (Vollweg: print(vofi_compare(vofi_read_scenario(vofi_example('s1_wu_mfh_1963_eh70')))) bzw. vofi_report)

### MRE-03 [major] erwerb_sanierung: Eine neue Gas-, Öl- oder Flüssiggasheizung zählt nicht als § 43-Heizung, daher fehlen § 5a CO2KostAufG und die Bio-Treppe; der Mietpfad stuft dieselbe Heizung abweichend ein

- **Ort:** R/expand-energy.R:277-278 (existing <- project_type %in% vocab('project_type')$existing_building) → co2_section43(); dagegen R/type-flow-rent-path.R:868 (existing = nicht neubau/erwerb_neubau)
- **Beschreibung:** Der Energie-Expander prüft 'Bestandsgebäude' über die Vokabelliste existing_building = [sanierung_eh, sanierung_einzelmassnahmen, sanierung_stufenweise, heizungstausch]. Diese Liste beschreibt Bestandsprojekte im Sinne der KPI- bzw. Referenzpflicht und enthält erwerb_sanierung nicht. Ein gekauftes Bestandsgebäude ist für § 43 GModG aber ein Bestandsgebäude. Bei erwerb_sanierung wird eine neu eingebaute Gasheizung deshalb nicht als section43 markiert: Der Vermieter trägt ab 2028 nicht die festen 50 % von CO2-Kosten und Gasnetzentgelt, und ab 2029 fehlen Bio-Anteil und Bio-Mehrkosten. Der Mietpfad behandelt dieselbe Heizung dagegen als § 43-Heizung (keine 15-%-Pauschale nach § 559e). Die beiden Modulteile widersprechen sich also.
- **Erwartet:** S3 base mit project_type erwerb_sanierung (Gas-BW eingebaut 2027-10-01), 2028: co2_landlord −746,33, network_fee_landlord −1.370,63, Mieter-Heizkosten 10.626,28; 2029: bio_landlord −375,06 (wie bei heizungstausch)
- **Tatsächlich:** 2028: co2_landlord −298,53 (Stufenmodell 20 %), network_fee_landlord 0, Mieter-Heizkosten 12.463,08; 2029: bio_landlord 0
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/me/repro/r3_erwerb_sanierung.R

### MRE-04 [major] § 558 im Vergleichsmieten-Modus bei Mietbeginn nach dem Stichtag (Neubau): Erhöhung schon im ersten Mietmonat, ohne 15-Monats-Wartefrist

- **Ort:** R/type-flow-rent-path.R: rp_inputs() (last558 Default valuation_date − 12, m_last0 = min(mi(last558), 0)) und rp_simulate() Schritt (f)
- **Beschreibung:** Die Wartefrist rechnet ab m_last0, abgeleitet aus last_558_increase_date mit Default 'Stichtag − 12 Monate'. rent_start wird nicht berücksichtigt. Beginnt die Vermietung nach dem Stichtag (Neubau mit Token completion, neue Gruppe), gilt die Wartefrist schon bei Mietbeginn als erfüllt. Die Erstvermietungsmiete wird dann sofort auf OVM bzw. Kappungsgrenze angehoben. Nach § 558 Abs. 1 muss die Miete aber 15 Monate seit Mietbeginn unverändert sein, die erste Erhöhung ist also frühestens mi(rent_start) + 15 möglich.
- **Erwartet:** Erstvermietung 10,00 ab 2029-01-01, OVM 11,50: Miete 10,00 bis 2030-03, frühestens ab 2030-04-01 11,50. S2 mit increase_policy max und OVM 14: Miete 2029 = 374.400 (13,00 × 2.400 × 12)
- **Tatsächlich:** 11,50 ab 2029-01-01, dem ersten Mietmonat. S2: rent 2029 = 420.182,10 (≈ 14,59 EUR/m² ab Fertigstellung, also +45.782 EUR im ersten Jahr)
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/me/repro/r4_wartefrist.R (Fall c); Vollszenario: vofi_run(vofi_build(vofi_read_scenario(vofi_example('s2_wu_neubau_mfh_36we')), overrides = list('unit_groups.wohnen.increase_policy'='max','unit_groups.wohnen.ovm_eur_m2_month'=14,'unit_groups.wohnen.growth_from'=NULL)))

### MRE-05 [minor] Nach dem Ende von Staffel oder Mietbindung ist eine § 558-Erhöhung schon 12 statt 15 Monate nach der letzten Mietänderung möglich

- **Ort:** R/type-flow-rent-path.R: rp_simulate() Schritte (a) Staffel und (c) Bindung setzen m_last nicht; Phase p558 beginnt bei mi(letzte Staffel) + 12 bzw. bei binding_end
- **Beschreibung:** Nur die Schritte (d) fixed_growth und (f) § 558 setzen m_last. Staffelstufen (§ 557a) und Erhöhungen der Bewilligungsmiete sind keine Erhöhungen nach §§ 559 bis 560 und zählen für die Wartefrist nach § 558 Abs. 1. Weil die Phase p558 schon 12 Monate nach der letzten Staffel beginnt, kommt die erste § 558-Erhöhung 3 Monate zu früh. Bei der Bindung gilt dasselbe ab binding_end, wenn die letzte Erhöhung der Bindungsmiete weniger als 15 Monate zurückliegt. In der Spec ist das nicht geregelt (1.8.7 nennt nur §§ 559/560 als Ausnahme).
- **Erwartet:** Staffel 2028-01-01: 8,30 und 2029-01-01: 8,60, OVM 10: erste § 558-Erhöhung frühestens 2030-04-01. Bindung bis 2030-01-01 mit Stufe 2029-01-01: frühestens 2030-04-01
- **Tatsächlich:** § 558-Erhöhung auf 9,60 bzw. 9,00 jeweils schon am 2030-01-01
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/me/repro/r4_wartefrist.R (Fälle a und b)

### MRE-06 [minor] § 559c: Kostengrenze ohne Anrechnung früherer § 559-Erhöhungen (Abs. 2), und die 5-Jahres-Sperre (Abs. 4) blockiert auch weitere vereinfachte Erhöhungen

- **Ort:** R/type-flow-rent-path.R: rp_simulate() (c559 sammelt nur Erhöhungen mit proc = bgb_559c; locked gilt für alle Verfahren); 01b §1.9.2
- **Beschreibung:** Nach § 559c Abs. 2 mindern Kosten früherer Erhöhungen der letzten fünf Jahre 'nach Absatz 1 oder nach § 559' die Grenze von 10.000 EUR je Wohnung. Code und Spec 1.9.2 zählen nur § 559c-Kosten. Umgekehrt sperrt § 559c Abs. 4 nach einer vereinfachten Erhöhung nur 'Mieterhöhungen nach § 559'; weitere vereinfachte Erhöhungen innerhalb der Restgrenze setzt Abs. 2 gerade voraus. Der Code sperrt jede Umlage, also auch die zweite § 559c-Erhöhung. Zusätzlich fällt auf (minor): Nach § 559c Abs. 1 S. 3 ist der Härteeinwand (§ 559 Abs. 4) ausgeschlossen, hardship_share wirkt aber auf alle Verfahren. Der Rechtsparameter s559.hardship_exclusion_not_for wird nirgends verwendet.
- **Erwartet:** (a) 1 WE, 70 m², § 559c je 4.000 EUR in 2027 und 2029: Umlage k2 ab 2030 = 0,08 × 0,7 × 4.000 = 224 EUR/a. (b) § 559 mit 8.000 EUR in 2027, dann § 559c mit 4.000 EUR in 2029: Restgrenze 2.000 < 4.000, also Rückfall auf § 559: 320 EUR/a
- **Tatsächlich:** (a) k2 = 0 mit W 'Sperrfrist nach § 559c Abs. 4'. (b) k2 = 224 EUR/a nach § 559c (Verfahrenscode 2)
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/me/repro/r5_559c.R


## Mietrecht/Energie/CO2

### EF-01 [major] Amortisation (payback_time/payback_year) bei Bestandsprojekten ohne Bestandswert trivial 0 Jahre bzw. Stichtagsjahr und ohne Vermerk ausgegeben (Seed-Beobachtung S1)

- **Ort:** R/kpi-value.R:kpi_payback_col / R/kpi-core.R:kpi_wealth, kpi_rwp; Ausgabe R/methods-result.R:rep_head_kpis, R/methods-compare.R:rep_cmp_kpis/rep_cmp_kpi_note, Bericht (Kopfkennzahlen, Amortisationsmarke)
- **Beschreibung:** Das ist ein Defekt, keine sinnvolle Amortisation. Ursache: W_t = BS_t + RWP_t. Im Fachmodus ist die Basis des Restwertpfads 'method', also der Wert des ganzen Gebäudes ab t = 0. Ohne building.existing_value_eur enthält aber weder EL_0 (Sacheinlage) noch die Unterlassungsalternative dieses Gebäude. In S1 base: BS_0 = -425.696,50, RWP_0 = 1.801.145, BS^U_0 = 151.488,50. Damit ist d_0 > 0 und bleibt > 0, also t* = 0 und payback_time = 0, payback_year = 2027. Gleiches gilt für v2_eh70 (deterministisch 0). In der MC sind 307 von 400 Läufen 0 und 92 Läufe 1, das ergibt den Mittelwert 0,2-0,3 Jahre der Seed-Beobachtung. Spec 12.3a sagt selbst, dass payback_time gegenüber der Unterlassung im Bestand nicht als Vorteilhaftigkeit lesbar ist. roe_* bekommt dafür NA no_existing_value, ΔEW den Vermerk '*'. Die Amortisation erscheint dagegen ohne jeden Vermerk: print(vofi_result) 'Amortisationsjahr 2027', vofi_compare-Tabelle 'Amortisationsdauer 0,0 Jahre' (base und v2), HTML-Bericht in den Kopfkennzahlen und als Amortisationsmarke im Diagramm 'Vermögensdifferenz zur Unterlassungsalternative'. Auch payback_time_ex_rv (S1 base 10 Jahre) enthält Bestandszahlungen. Gegenprobe: Mit existing_value_eur = 1,8 Mio wird die Kennzahl sinnvoll (base no_payback, v2 12 Jahre). S3 (heizungstausch) zeigt aus demselben Grund 1 Jahr.
- **Erwartet:** Bei Bestandsprojekten ohne Bestandswert payback_time/payback_year (mit und ohne Restwert) als NA mit Code no_existing_value, analog zu roe_*. Mindestens aber derselbe Vermerk wie bei ΔEW ('enthält Bestandszahlungen') und keine Kopfkennzahl. Primär ist dort payback_vs_reference (12.3a).
- **Tatsächlich:** S1 base und v2_eh70: payback_time = 0,0 Jahre, payback_year = 2027 (MC-Mittel v2 0,2 Jahre), ohne Vermerk in print, Vergleichstabelle und Bericht.
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/ef/repro/f1_payback_bestand.R (Gegenprobe mit Bestandswert: f1b_with_value.R im selben Ordner; Pfad des Pakets über VOFI_PKG)

### EF-02 [major] MC-Vergleich: Amortisationsstatistik nur über Läufe mit Amortisation, NA-Anteil fehlt (diff_stats, print)

- **Ort:** R/compare.R:cmp_assemble (diff_stats: x[!is.na(x)], keine Spalte na_share/n_valid); R/methods-compare.R print (Kennzahlen je Variante und Vergleich gegenüber der Referenz)
- **Beschreibung:** vofi_compare(n_sim > 1) bildet Mittel und Quantile von payback_vs_reference(_ex_rv) und der per-Variante gezeigten payback_time nur über die Läufe mit Amortisation. Läufe ohne Amortisation (NA no_payback) fallen einfach weg. diff_stats hat keine Spalte für den NA-Anteil, und print zeigt ihn weder dort noch in der Variantentabelle (kpi_table hätte na_share). Beispiel S1 (n_sim = 200, seed = 1): 'Amortisation gegenüber der Referenz (ohne Restwert)' Mittel 27,9 / Median 28,0 / P95 30 Jahre, obwohl 92,5 % der Läufe keine Amortisation haben. Mit Restwert fehlt sie in 9 % der Läufe. Kleines Beispiel: 'Amortisationsdauer base 9,5 Jahre', obwohl 77 % der base-Läufe nie amortisieren. Wer das liest, schließt auf eine typische Amortisation, die es in der Mehrzahl der Läufe nicht gibt (Survivorship-Verzerrung). vofi_mc() selbst zeigt den NA-Anteil korrekt.
- **Erwartet:** NA-Anteil (bzw. n_valid) je Vergleichskennzahl in diff_stats und in print/Bericht ausweisen. Für Amortisation 'keine Amortisation' als zensierten Wert behandeln, z. B. Quantile mit '> Horizont' oder P(Amortisation im Horizont) zusätzlich zeigen.
- **Tatsächlich:** Median 28 Jahre bei 92,5 % Läufen ohne Amortisation (S1). 'Amortisationsdauer 9,5 Jahre' bei 77 % NA (Kleinfall). Kein Hinweis auf den Anteil.
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/ef/repro/f2_mc_payback_na.R (S1-Variante als Kommentar im Skript)

### EF-03 [major] Eigenanteil nach Förderung (own_contribution) zählt künftige Maßnahmen nominal mit und kehrt den Variantenvergleich um

- **Ort:** R/kpi-household.R:kpi_calc_own_contribution (Summe über alle t)
- **Beschreibung:** own_contribution summiert capex aller Perioden. Bei Bestandsszenarien sind spätere Erneuerungen als Maßnahmen modelliert (Kategorie capex, nicht replacement), und die gehen nominal in den 'Eigenanteil heute nach Förderung' ein. S1 base: 323.246 €, davon 173.246 € für die Maßnahme 'ersatz_heizung_2047' (Periode 2046). S1 v2_eh70: 233.553 €, davon 82.064 € für 'anstrich_wdvs_2047'. Zum Stichtag beträgt der Eigenanteil base 150.000 € und v2 151.488,50 €, das entspricht auch der Einlage ek__in von 151.488,50 €. In der Vergleichstabelle wirkt v2 also rund 90.000 € günstiger beim Eigenanteil, obwohl es heute 1.488 € mehr Eigenkapital braucht. Nach dem Wortlaut der Formel in Spec 12.3 (Σ_t) ist das konform. Es widerspricht aber dem Konzept ('Eigenanteil heute nach Förderung (Einmalbetrag)') und der Absicht 'ohne Ersatzinvestitionen' (R-83). Außerdem werden Beträge aus 20 Jahren Abstand nominal addiert.
- **Erwartet:** Eigenanteil heute: nur Investitionen der Bau- bzw. Maßnahmenphase (t = 0 bzw. Fenster W / Fertigstellung der Erstmaßnahmen), oder künftige Maßnahmen getrennt bzw. als Barwert ausweisen.
- **Tatsächlich:** base 323.246 € vs. v2 233.553 €. Mit nur den Erstinvestitionen wären es 150.000 € vs. 151.488 €.
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/ef/repro/f3_own_contribution.R

### EF-04 [minor] Rendite der Mehrinvestition: 'nicht monoton' auch bei streng monotonem g; keine Zensurangabe, daher in allen Bestands-Referenzszenarien n. d.

- **Ort:** R/solve.R:slv_incremental (monotone = !is.na(v)); R/kpi-returns.R:kpi_incremental_return
- **Beschreibung:** slv_incremental setzt monotone = !is.na(v). Damit heißt jede fehlende Nullstelle 'nicht monoton'. Beispiel S4 v2_nur_wp: g(h) = delta_vs_reference(h) fällt auf [-0,02; 0,15] streng von 84.024 € auf 20.368 €, die Rendite der Mehrinvestition liegt also über 15 %. Ausgegeben werden 'nicht monoton' und 'n. d.'. In S1 v2_eh70, S3 v2_wp_pv und S4 v1_isfp_stufen ist g auf dem ganzen Intervall positiv (U-förmig): Die Variante dominiert bei jedem Habenzins, weil die Mehrinvestition fremdfinanziert ist. Auch das wird als 'nicht monoton / n. d.' gezeigt. Spec 12.3a nennt incremental_return als Renditekennzahl für Bestandsprojekte. In allen drei Bestands-Referenzszenarien ist sie damit n. d., und die Begründung ist teils falsch.
- **Erwartet:** monotone aus den Stützwerten bestimmen. Bei g > 0 auf dem ganzen Intervall bzw. fallend ohne Vorzeichenwechsel den Fall benennen ('Rendite > 15 %' bzw. 'Variante dominiert bei jedem Habenzins'), statt nur 'nicht monoton'.
- **Tatsächlich:** S4 v2_nur_wp: g streng fallend (min 20.368 € > 0), Ausgabe 'nicht monoton', monotone = FALSE, Ergebnis n. d.
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/ef/repro/f4_incremental_return.R

### EF-05 [minor] ltv_max/lending_ratio_max werden vom Stand in t0 bzw. der Bauphase bestimmt (S2 567 %, S3 369 %)

- **Ort:** R/kpi-realestate.R:kpi_ltv_path, typedef_kpi_ltv_max, kpi_calc_lending_ratio_max
- **Beschreibung:** LTV und Beleihungsauslauf nehmen das Maximum über alle t, also auch t0 und die Bauphase. Dort ist der Kredit schon voll ausgezahlt, der Wertpfad V_t enthält die noch nicht fertige Maßnahme aber noch nicht. S2 base: t0 Bankdarlehen 5,1 Mio gegen V_0 = 900.000 (Grundstück), also ltv_max = 5,667 und lending_ratio_max = 6,296. Danach liegt der LTV bei 1,23 / 0,76 / 0,91. S3 v2_wp_pv: t0 Kredit 142.060 gegen V_0 = 38.500, also ltv_max = 3,690 und lending_ratio_max = 4,100. Ab t = 1 liegt er bei ≤ 0,715. Die Formel ist spec-konform. Anders als DSCR/ICR, die erst ab P_stab rechnen, ist das Ergebnis hier aber ein Zeitpunkt-Artefakt, und ltv_max ist MC-Default-Kennzahl. Ein LTV von 567 % bzw. 369 % in Kopf- und MC-Ausgaben ist irreführend.
- **Erwartet:** LTV/Beleihungsauslauf ab Fertigstellung bzw. Stabilisierungsjahr auswerten, oder den Wert der Bauphase getrennt bzw. gekennzeichnet ausweisen.
- **Tatsächlich:** S2 ltv_max 5,67 / lending_ratio_max 6,30; S3 v2 ltv_max 3,69 / lending_ratio_max 4,10, jeweils aus t0.
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/ef/repro/f5_ltv_t0.R


## Förderung/Expander, MC/Statistik

### FE-01 [major] Endfällige Bibliotheksvarianten (KfW 261 und KfW 300, b10_10_10) brechen den Aufbau ab

- **Ort:** R/expand-funding.R:fund_build_loan (übernimmt grace_years der Variante) und R/type-inst-loan-core.R (Prüfung grace_too_long, ca. Zeile 1049, läuft vor dem Rücksprung für bullet)
- **Beschreibung:** Wählt man die endfällige Variante b10_10_10 aus der Bibliothek, kopiert der Expander grace_years = 10 und term_years = 10 in den bullet_loan. Die allgemeine Kreditprüfung verlangt grace < term und läuft vor dem Rücksprung `if (identical(repayment, "bullet")) return(...)`. Bei einem endfälligen Darlehen ist die tilgungsfreie Zeit aber gleich der Laufzeit. Damit ist jede endfällige Variante der Bibliothek unbenutzbar, obwohl Memo 02 §5.1 und §5.6 sie ausdrücklich nennen.
- **Erwartet:** Ein endfälliges Darlehen über 10 Jahre: 10 Jahre nur Zinsen, Schlusstilgung in Jahr 10 (bei KfW 261 abzüglich Tilgungszuschuss)
- **Tatsächlich:** vofi_build() bricht ab: "'financing.f_kfw261_loan.grace_years': die tilgungsfreie Zeit (10 Jahre) muss kürzer als die Laufzeit (10 Jahre) sein." Bei S5 mit KfW 300 tritt derselbe Fehler auf.
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/fe_work/repro/r01_bullet.R (S1 V2 bzw. S5 V2 mit loan_variant: b10_10_10)

### FE-02 [major] § 35c: Höchstbetrag 40.000 EUR je Objekt wird nur je Instrument geprüft

- **Ort:** R/type-flow-tax-credit-35c.R (cap_total je Komponente); R/expand-funding.R fund_build_35c/fund_cumulation (keine Prüfung über Instrumente hinweg)
- **Beschreibung:** Jedes Instrument vom Typ tax_credit rechnet seinen eigenen Deckel von 40.000 EUR (Abzug prior_used_eur nur nach manueller Angabe). Zwei § 35c-Instrumente am selben Gebäude, typisch bei stufenweiser Sanierung, ergeben zusammen mehr als 40.000 EUR, und weder Validierung noch Expander melden etwas.
- **Erwartet:** Insgesamt höchstens 40.000 EUR je Objekt (§ 35c Abs. 1 EStG). Das zweite Instrument wird auf 10.000 EUR begrenzt, oder es kommt mindestens eine E- bzw. W-Meldung.
- **Tatsächlich:** WP 2027 mit 150.000 EUR ergibt 10.500/10.500/9.000, Dach 2028 mit 150.000 EUR ergibt 10.500/10.500/9.000. Summe 60.000 EUR, keine Meldung zu § 35c.
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/fe_work/repro/r02_35c_objektdeckel.R (S4 v2_nur_wp, funding.c1 und c2 aus funding/estg_35c)

### FE-03 [major] Restwert market_growth: Investitionsbasis enthält alle capex des Horizonts (auch künftige) als Wert zum Stichtag

- **Ort:** R/type-flow-residual-value.R:rv_invest_base / rv_market_growth
- **Beschreibung:** Ohne base_value_eur, existing_value_eur und market_value_eur gilt V_0 = −Σ_t (land, acquisition_cost, capex) über alle Perioden. Dadurch stehen (1) künftige Maßnahmen, etwa ein WP-Ersatz 2045, schon zum Stichtag im Marktwert und wachsen ab t = 0 mit, (2) bei Erwerbsprojekten zusätzlich die Sanierungskosten, entgegen 01a §6.3.4 ("Für Erwerbsprojekte ist die Investitionsbasis der Kaufpreis einschließlich Nebenkosten"), und (3) im Bestand ohne Bestandswert der Altbau gar nicht. Der Wert ist dann einfach das ausgegebene Geld. Eine Meldung gibt es nicht. Das Profil selbstnutzer setzt market_growth als Standard für erwerb_sanierung.
- **Erwartet:** Erwerb: V_0 = Kaufpreis + Nebenkosten = 324.000 EUR (300.000 + GrESt 19.500 + Notar 3.000 + Grundbuch 1.500). Künftige capex nie in V_0. Bestand ohne Ausgangswert: E oder W.
- **Tatsächlich:** Erwerb (Kauf 300.000, WP 2027, WP-Ersatz 2045): V_0 = 427.100,20 EUR. S4 (Bestand) mit market_growth: base V_0 = 172.599,15, V1 V_0 = 220.862,10 (Summe aller Maßnahmen 2027-2050), ohne Meldung.
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/fe_work/repro/r03_market_growth.R

### FE-04 [major] Haushaltsmodus: Amortisation 'sofort' (payback_vs_reference = 0,0 Jahre), weil der Zeitwert bei Fertigstellung den Kosten entspricht (Seed a bestätigt)

- **Ort:** R/kpi-value.R:kpi_payback_vs_reference; R/report-views.R:rep_household_summary (pb_col = wealth_diff_vs_reference mit rv_path_basis measures); kpi_rv_basis (auto -> measures)
- **Beschreibung:** Im Haushaltsmodus gilt W_t = BS_t + RW_t(measures), und der Komponenten-Zeitwert ist bei Fertigstellung gleich den Kosten. Für eine Investition zum Stichtag ist d_0 daher genau 0. Sobald der Zuschuss den Wertverlust und den Zinsverlust des ersten Jahres übersteigt, bleibt d_t ≥ 0, und t* = 0 folgt aus der Konstruktion. Für S4 V1 und V2 meldet der Bericht 'Die Investition hat sich voraussichtlich 2027 bezahlt gemacht', also im Jahr der Investition. Ohne Restwert sind es 2049 (V1) bzw. 2030 (V2). Memo 07 §5.4 definiert das Amortisationsjahr über Guthaben − Restschulden und nennt den Zeitwert nur optional; das S4-Muster erwartet 'nach etwa vier bis fünf Jahren'. Die Rechnung folgt R-72 formal, für Haushalte ist die Aussage aber irreführend.
- **Erwartet:** Für S4 V2 eine Amortisation von etwa 4-5 Jahren (Memo 07, ohne Restwert 2030), V1 2049. Mindestens: kein 'bezahlt gemacht' im Investitionsjahr; den Wert ohne Restwert neben dem Zeitwert ausweisen.
- **Tatsächlich:** payback_vs_reference 0,00 und payback_year_vs_reference 2027 für V1 und V2 (ohne Restwert: 23 bzw. 4 Jahre). Klartext: 'Die Investition hat sich voraussichtlich 2027 bezahlt gemacht (Vermögensvergleich mit dem Zeitwert der Maßnahmen).'
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/fe_work/repro/r04_payback_null.R

### FE-05 [major] Haushalts-Klartexte S4 V1 widersprechen sich; Kontokorrentzinsen fehlen in der Belastung

- **Ort:** R/report-views.R:rep_household_summary (total_saving, total_cost); Spec 00 §7.6 Kategorientabelle (overdraft/interest ohne burden)
- **Beschreibung:** Für S4 V1 stehen im selben Bericht folgende Aussagen: 'Über 25 Jahre zahlen Sie gegenüber base insgesamt rund 70.100 € mehr' (total_saving = Σ Belastungsdifferenz), dagegen 'Über 25 Jahre zahlen Sie insgesamt rund 253.500 €' gegenüber 285.800 € bei base, also 32.300 € weniger. Ohne Restwert ist das Vermögen um 78.405 € höher, und dazu kommt 'bezahlt gemacht 2027'. Ursache: Die Belastung enthält die Tilgung der KfW-358-Kredite (Finanzierung der V1-Investitionen). Nicht enthalten sind Investitionen aus Erspartem bzw. Kontokorrent der Referenz und die Kontokorrentzinsen, obwohl S4 das Kontokorrent ausdrücklich als 'Ergänzungskredit' führt. Diese Zinsen betragen 169.210 € (base), 94.241 € (V1) und 136.144 € (V2). So erscheint die kreditfinanzierte Variante teurer, die aus dem Kontokorrent finanzierte billiger. Memo 07 §5.4 definiert die Belastung als 'Zinsen + Tilgung + Energie …'.
- **Erwartet:** Konsistente Klartexte: Belastung und Gesamtkosten mit derselben Finanzierungsbasis, Zinsen der Ergänzungsfinanzierung (Kontokorrent) in der Belastung oder ausdrücklich ausgewiesen
- **Tatsächlich:** total_saving −70.135,04; total_cost 253.467,83 (V1) gegenüber 285.831 (base); delta_vs_reference_ex_rv +78.404,89; Kontokorrentzinsen base 169.210, V1 94.241 (Spalte 'interest' der Haushaltssicht bei base durchgehend 0)
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/fe_work/repro/r05_haushalt_texte.R

### FE-06 [major] 'Eigenanteil nach Förderung (Einmalbetrag)' hängt von der Modellierungsform ab und ist kein Einmalbetrag (Seed b)

- **Ort:** R/kpi-household.R:kpi_calc_own_contribution; R/report-views.R und inst/labels/de/report.yaml (Text 'Einmalbetrag')
- **Beschreibung:** own_contribution summiert capex nominal über den ganzen Horizont, Ersatzzyklen (Kategorie replacement) bleiben draußen. Dieselbe wirtschaftliche Sache zählt damit je nach Form: S1 base enthält den Heizungsersatz 2047 als Maßnahme (173.246,40 €), S1 V2 enthält den WP-Ersatz 2047 als Ersatzzyklus nicht (338.104,02 €), ebenso nicht den Fassadenersatz 2042 in base (133.673,60 €). Im Haushaltsmodus heißt die Summe künftiger Maßnahmen 'Einmalbetrag' (S4 base: 172.600 € = Maßnahmen 2030-2050, V1 enthält den WP-Ersatz 2047). Zuschüsse werden abgezogen, der Tilgungszuschuss nicht (S1 V2: 144.400 €). Die Seed-Werte 366.330 (base) und 441.420 (V2) sind MC-Mittel: Bei festem Kreditbetrag trägt der Eigenanteil die Kostenüberschreitungen (E[PERT 0,95/1,05/1,25] = 1,0667, E[PERT 0,95/1,10/1,50] = 1,1417; deterministisch 323.246,40 bzw. 233.552,60). Die Rangfolge kehrt sich also um, und die 2047-Behandlung ist uneinheitlich.
- **Erwartet:** Einheitliche Definition für alle Varianten: Erstinvestition ohne Ersatz- und Erhaltungsmaßnahmen späterer Jahre (R-83 'ohne Ersatzinvestitionen') und Tilgungszuschuss wie Zuschuss, oder Ausweis je Zahlungsjahr statt 'Einmalbetrag'
- **Tatsächlich:** S1 deterministisch base 323.246,40 (inkl. Ersatz 2047) gegenüber V2 233.552,60 (ohne WP-Ersatz 2047, ohne TZ-Abzug); S4 base 'Einmalbetrag' 172.600 € = Summe 2030-2050
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/fe_work/repro/r06_eigenanteil.R

### FE-07 [minor] Bereitstellungsprovision der Förderkredite läuft ab der ersten Auszahlung statt ab der Zusage

- **Ort:** R/expand-funding.R:fund_build_loan (fees ohne commitment_date); 01b §4.6 Belegungstabelle; 01a §5.2 commitment_date Default = start
- **Beschreibung:** Der Expander gibt nur processing_fee_share, commitment_fee_rate_month und commitment_free_months weiter, ein Zusagedatum nicht, und es lässt sich für funding.<f> auch nicht setzen. Die 12 freien Monate beginnen damit bei der ersten Teilauszahlung. Memo 02 (§5.1, §5.5) nennt '0,15 %/Monat ab 13. Monat' nach Zusage. Bei Neubauten mit gestaffelter Auszahlung fehlt die Provision deshalb systematisch.
- **Erwartet:** S2 base (KfW 298, 40 % am 2027-12-31, 60 % am 2028-12-31, Zusage etwa Januar 2027): 2.160.000 × 0,0015 × 12 = 38.880 EUR (V2: 3.240.000 × 0,0015 × 12 = 58.320 EUR)
- **Tatsächlich:** loan_f_kfw298_loan_fees = 0 (base und V2). Gegenprobe mit gleichem manuellem Kredit und commitment_date 2027-01-01: −38.880 in 2028.
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/fe_work/repro/r07_bereitstellung.R

### FE-08 [minor] KfW 358/359 ohne Zusagebetrag: Kredit = volle Kostenschätzung, Zuschuss nicht abgezogen (Überfinanzierung)

- **Ort:** R/expand-funding.R:fund_build_loan (amount_text = pmin(Σ e_m · cost_eur · max_share, Deckel))
- **Beschreibung:** Memo 02 §5.4 und §5.8 setzen für den Ergänzungskredit L_E = min(K_ff − G, 120.000 · WE). Der Bibliothekseintrag vermerkt 'praktisch Kosten minus Zuschuss'. Der Expander nimmt die vollen Kosten im Preisstand, Kredit und BEG-EM-Zuschuss zusammen übersteigen dann die Kosten. Eine W 'bitte Zusagebetrag eintragen' wird ausgegeben, aber die Vorbelegung widerspricht dem Programm.
- **Erwartet:** S4 V1 kfw358_2030 ohne amount_eur: min(Kosten − Zuschuss, 120.000) = 85.988,87 − 10.500 = 75.488,87 (realisiert) bzw. 65.900 (Preisstand)
- **Tatsächlich:** Auszahlung 76.400,00 + BAFA 10.500,00 = 86.900 > Kosten 85.988,87
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/fe_work/repro/r08_kfw358_betrag.R

### FE-09 [minor] KfW 308 (Erwerb) ohne amount_eur: Validierungsfehler auf einen nicht vorhandenen Pfad measures.<kauf>.cost_eur

- **Ort:** R/expand-funding.R:fund_build_loan (amount_text nutzt measures.<m>.cost_eur); Erwerbsmaßnahmen haben nur purchase_price_eur
- **Beschreibung:** Bei KfW 308 ist die geförderte Maßnahme der Kauf (erwerb_objekt). Der Expander schreibt den Ausdruck '(pmin((measures.kauf.cost_eur), 140000))', die Validierung bricht ab. 01b §4.6 nimmt an, measures.m.cost_eur existiere immer (rule:cost_from_kg), für Erwerbsmaßnahmen stimmt das nicht. Mit gesetztem amount_eur läuft es (getestet).
- **Erwartet:** Kreditbetrag aus min(Kaufpreis (bzw. Gebäudeanteil) + Nebenkosten, Deckel nach Kinderzahl) mit W, oder E mit klarer Aufforderung, amount_eur zu setzen
- **Tatsächlich:** Fehler: "Ausdruck '(pmin((measures.kauf.cost_eur), 140000))': der Pfad 'measures.kauf.cost_eur' existiert nicht"
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/fe_work/repro/r09_kfw308.R

### FE-10 [minor] Zusagebetrag über Kreditdeckel und förderfähigen Kosten ohne Befund; Tilgungszuschuss auf 150.000 EUR/WE statt auf die förderfähigen Kosten

- **Ort:** R/expand-funding.R:fund_repayment_grant (share = (t · pmin(amount − cs, cap·N) + 0,5·cs)/amount); Validierung der Förderkredite
- **Beschreibung:** Wenn amount_eur gesetzt ist, wird der TZ auf min(Zusage − Baubegleitung, 150.000 · N) berechnet, ohne Bezug auf die förderfähigen Kosten der Maßnahmen. Es gibt keine Plausibilitätsmeldung für Zusage > Kreditdeckel (+ Baubegleitungsdeckel) oder Zusage > förderfähige Kosten. fund_total_share schlägt nur an, wenn die Summe über den Kosten liegt.
- **Erwartet:** W bei Zusage > 150.000 · 24 + 40.000 bzw. > förderfähige Kosten; TZ höchstens 0,10 × 1.451.488,50 + 0,5 × 36.000 = 163.148,85
- **Tatsächlich:** S1 V2 mit amount_eur 5.000.000: keine Meldung, TZ 378.000,00 (= 0,10 × 3.600.000 + 18.000)
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/fe_work/repro/r10_zusage_deckel.R

### FE-11 [minor] Kennwert der Instandhaltungsprüfung (replacements_excluded) ohne Ersatzzyklen der Maßnahmen, aber mit vollen Kosten energetischer Maßnahmen

- **Ort:** R/validate-plausibility.R:val_plaus_maintenance (Summe nur building.elements.*.replacement_cost_eur und erhaltung/Ohnehin-1-Maßnahmen)
- **Beschreibung:** 01a §4.11.4 und M7 verlangen als Kennwert die expliziten Ersatz- und Erhaltungszahlungen im Horizont. Ersatzereignisse der Maßnahmen (replacement.enabled mit replacement.cost_eur) fehlen. Bauteile werden einmal gezählt, unabhängig von der Zahl der Ersatzereignisse. Energetische Maßnahmen mit Katalogklassifikation 'erhaltung' gehen dagegen mit vollen Kosten ein. Die Info-Meldung misst damit nicht die Doppelzählung von Pauschale und Erneuerung.
- **Erwartet:** S1 base: (126.787,5 + 321.195 + 129.202,5 + 95.000 + Fassadenersatz 82.500)/(30 · 1.600) = 15,72 €/m²·a; V2 mit WP-Ersatz 180.000, ohne volle Hüllen- und Heizungskosten
- **Tatsächlich:** base 14,00385 (ohne Ersatzzyklus Fassade); V2 29,31834 (huelle 990.580,50 + heizung 371.700 + Anstrich 45.000 gezählt, WP-Ersatz 2047 mit 180.000 nicht)
- **Reproduktion:** /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/fe_work/repro/r11_kennwert.R


## Förderung/Expander, MC/Statistik

### MCS-01 [major] Haupttreiber im Bericht kommen bei Vergleichen aus der Referenzvariante und messen nicht den Vergleich

- **Ort:** R/report-html.R:rep_html_context() (base = rep_comparison_result(cmp, NULL)) und rep_html_drivers() (Rückfall auf die Rangkorrelationen von rc$mc)
- **Beschreibung:** Wird kein Sensitivitätsobjekt übergeben, nimmt der Bericht die Treiber aus rep_rank_correlations(rc$mc, …). rc$mc ist bei einem vofi_comparison das MC-Ergebnis der Referenz (baseline). Die Kennzahl ist deren eigenes delta_terminal_value. Bei Bestandsprojekten ist das der Rückfall von rep_mc_primary(), also ΔEW der Referenz gegen ihre eigene Unterlassung. Diese Größe ist laut 12.3a ausdrücklich nicht als Vorteilhaftigkeit lesbar. Die Eingaben, die nur in der Variante vorkommen (JAZ, Einsparwirkung, KfW-358-Zins, BAFA-Zusage), fehlen ganz. Satz im Bericht (Haushalt und Fachmodus): „Am stärksten hängt das Ergebnis von … ab.“ Das betrifft Seed (b).
- **Erwartet:** Treiber von delta_vs_reference (Variante gegen Referenz, Differenz je Lauf; Teil C 6.4, Memo 07 §5.4 Nr. 7). S4, n_sim = 400, Spearman mit delta_vs_reference: funding.bafa_2033.approved 0,65, construction_price_shift 0,39, energy_price_gas.mean 0,32, rate_kfw358_2030 −0,24. Der Tornado auf delta_vs_reference ergibt dieselbe Reihenfolge: BAFA-Zusage, Baupreisabweichung, Bauzins, Gaspreis, Zins KfW 358.
- **Tatsächlich:** „Habenzins, Wachstum Gasnetzentgelte p. a. und energy_price_gas.growth“ bei n_sim = 400, bzw. „… und CO2-Preis 2030“ bei n_sim = 200. Das sind exakt die drei stärksten Spearman-Werte der Referenzeingaben mit dem ΔEW der Referenz (deposit_rate −0,30, network_fee_growth_gas −0,24, energy_price_gas.growth −0,15). Mit delta_vs_reference korreliert der Habenzins nur mit −0,04 bis −0,05.
- **Reproduktion:** Rscript /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/mcs/repro/repro_s4_report.R /home/user/VoFi  (Abschnitt F1: rep_html_drivers(rep_html_context(list(main = cmp), 'household', list(name='x'))) gegen die Spearman-Werte von cmp$differences$delta_vs_reference)

### MCS-02 [major] Haushaltstext „Über 25 Jahre zahlen Sie … insgesamt rund 70.100 € mehr“ lässt die Einmalbeträge weg und widerspricht den eigenen Gesamtkosten

- **Ort:** R/report-views.R:rep_household_vs_ref() (cumulative_saving) und rep_household_summary() (Element total_saving)
- **Beschreibung:** total_saving ist die kumulierte Differenz der Monatsbelastung. Investitionen aus Eigenmitteln gehören laut Definition nicht zur Monatsbelastung, im Vergleich fehlen sie damit vollständig. In S4 bezahlt base alle Ohnehin-Maßnahmen (Kessel, Dach, Anstrich, Fenster, WP 2050) aus dem Ersparten: Eigenanteil 172.600 €. V1 finanziert über KfW 358 (Zins und Tilgung stehen in der Belastung), Eigenanteil 70.100 €. Dieselbe Zusammenfassung weist als total_cost (Eigenanteil plus Belastung) 285.800 € für base und 253.500 € für V1 aus. V1 zahlt also insgesamt rund 32.400 € weniger, der Text behauptet 70.100 € mehr. Zusammen mit „In 10 von 10 simulierten Zukünften ist v1 besser“ und der grünen Ampel entsteht genau der Widerspruch aus Seed (a). Ebenfalls auffällig: „hat sich voraussichtlich 2027 bezahlt gemacht“. payback_vs_reference ist in 100 % der Läufe 0, weil der Zeitwert der Wärmepumpe zum Bruttopreis und zugleich der Zuschuss gutgeschrieben werden (rechnerisch spec-konform nach 12.3, für Haushalte aber irreführend).
- **Erwartet:** Gesamtkosten über N Jahre = Summe aller variantenabhängigen Auszahlungen abzüglich Zuschüsse und Erlöse (Memo 07 §5.4), einschließlich der Einmalbeträge aus Eigenmitteln. Für S4: „Über 25 Jahre sparen Sie gegenüber base insgesamt rund 32.400 €“, passend zu total_cost.
- **Tatsächlich:** total_saving = −70.135 €, Text „zahlen … rund 70.100 € mehr“. Gleichzeitig total_cost base − V1 = +32.363 €. Abgleich: −70.135 + (172.599 − 70.101) = 32.363.
- **Reproduktion:** Rscript /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/mcs/repro/repro_s4_report.R /home/user/VoFi  (Abschnitt F2: attr(vofi_household_view(cmp), 'summary'), Elemente total_saving, total_cost, own_contribution)

### MCS-03 [major] Bandbreite der Monatsbelastung nur für das erste Jahr, ohne Zeitbezug; Marktpfade sind dort deterministisch

- **Ort:** R/report-views.R:rep_household_range() (Kennzahl monthly_burden_y1, Label report.household.text.range_burden)
- **Beschreibung:** Die Bandbreite in Worten verwendet q10 und q90 von monthly_burden_y1. Bei Stichtag 1.1. ist das erste volle Jahr das Startjahr der Prozesse. Dort ist Spalte 1 nach Spec 00 §11.7 der Startwert, Energiepreis- und Zinspfade sind also in allen Läufen gleich. Die Bandbreite spiegelt dann fast nur statische Größen wider (V1: JAZ). Der Text „Voraussichtlich rund 190 € pro Monat; in 8 von 10 simulierten Zukünften zwischen 180 € und 190 €“ nennt kein Jahr, wird als Belastung schlechthin gelesen und blendet das Energiepreisrisiko aus. Prüfung Seed (a): Das Overlay von S4 variiert die Energiepreise sehr wohl (Gaspreis 2051 0,044–0,21 €/kWh), die enge Spanne ist ein reines Artefakt von Jahr 1.
- **Erwartet:** Bandbreite mit Zeitbezug („im ersten vollen Nutzungsjahr“) und zusätzlich, oder stattdessen, für eine Größe, in der die Preisrisiken wirken, etwa monthly_burden_avg10 oder kpi_series$monthly_burden. Beispiel S4 base 2036 q05–q95: 323–423 €; V1: 454–768 €.
- **Tatsächlich:** base: „zwischen 300 € und 300 €“ (Monatsbelastung 2027, sd 1 €); V1: „zwischen 180 € und 190 €“. Die eigenen kpi_series zeigen dagegen für 2046 base 396–615 € und V1 490–882 € (q05–q95).
- **Reproduktion:** Rscript /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/mcs/repro/repro_s4_report.R /home/user/VoFi  (Abschnitt F3: Element range_y1 gegen cmp$results[[v]]$kpi_series$monthly_burden$quantiles)

### MCS-04 [major] Ein Override (Schicht 8) auf ein korreliertes Overlay-Ziel bricht mit einem Validierungsfehler ab; vofi_solve(rebuild = TRUE) ist für solche Parameter unbrauchbar

- **Ort:** R/scenario-variants.R:var_unbind_overlay(), aufgerufen aus R/scenario-layers.R:scn_apply_override_layer(); betrifft vofi_build(overrides=), slv_eval_rebuild() in R/solve.R und Pflichtsensitivitäten
- **Beschreibung:** Ein Override auf ein Overlay-Ziel entfernt den Overlay-Eintrag (die Bindung entfällt), lässt aber die Paare in stochastic.correlations.parameters stehen. Die Validierung meldet dann einen unbekannten Schlüssel (R-96). Damit scheitert der in Teil C 6.5 dokumentierte Ablauf „maximal tragbare Investition: param = shared.cost_factor_v2, rebuild = TRUE, Strukturtest S1“. Ebenso scheitert jeder vofi_build(overrides = …) auf cost_factor_v1/v2 (S1), co2_2030/co2_2040 (S1, S3, S4) oder jaz_s* (S4 V1).
- **Erwartet:** Laut §4.7 wird der Pfad für den Lauf deterministisch und die Bindung entfällt. Die Korrelationspaare dieses Schlüssels müssen dabei mitentfallen (mit vofi_inform), der Lauf rechnet normal.
- **Tatsächlich:** vofi_error_validation: „'stochastic.correlations.parameters.1': unbekannter Schlüssel 'cost_factor_v2'“. Derselbe Break-even ohne rebuild (Design-Lauf) funktioniert: 1,315135.
- **Reproduktion:** Rscript /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/mcs/repro/repro_override_corr.R /home/user/VoFi   # kurz: sc <- vofi_read_scenario(vofi_example('s1_wu_mfh_1963_eh70')); vofi_solve(sc, param = 'shared.cost_factor_v2', variant = 'v2_eh70', rebuild = TRUE)

### MCS-05 [minor] Rohschlüssel statt deutscher Bezeichnungen bei Treibern, Tornado und Varianten im Haushaltsbericht

- **Ort:** R/report-html.R:rep_html_input_label() (sucht nur stochastic.parameters/processes[[key]]$label), R/sensitivity.R:sens_static_candidate() (label = key), R/report-views.R:rep_household_summary(), R/report-html.R:rep_html_hh_risk_lines() (Variantennamen als ID)
- **Beschreibung:** Unsichere Prozessparameter (<proc>.<param>), automatisch erzeugte Förderzusagen (funding.<id>.approved) und Pfadmerkmale (<proc>.mean/.end/.at<jahr>) haben keinen Overlay-Label-Eintrag. Bericht und Tornado zeigen deshalb den rohen Schlüssel. Auch Varianten und Referenz erscheinen in den Haushaltstexten als ID statt mit ihrem label. Das betrifft Seed (b).
- **Erwartet:** Deutsche Bezeichnungen, z. B. „Erdgaspreis EFH: Trendwachstum“, „Förderzusage BAFA 2033“, „Bauzins (Mittel)“, „V1 iSFP stufenweise … besser als Gaskessel behalten“ (Spec 00 §2.10, Memo 07 §5.5 Label-Mapping).
- **Tatsächlich:** „energy_price_gas.growth“, „inflation.mu“, „funding.bafa_2033.approved“, „mortgage_rate.mean“ (S2-Treiber: „Mietsteigerung, mortgage_rate.mean, Erstvermietungsmiete“), „In 10 von 10 simulierten Zukünften ist v1_isfp_stufen besser als base“, „gegenüber base“.
- **Reproduktion:** Rscript /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/mcs/repro/repro_s4_report.R /home/user/VoFi  (Abschnitt F5: tor$params[, c('param','label')]; F1: Risikozeile)

### MCS-06 [minor] Bericht sortiert die globale Sensitivität mit dem falschen Bestimmtheitsmaß um

- **Ort:** R/report-html.R:rep_html_drivers() (r2 <- s$r2_src; Sortierung nach |SRRC|, wenn r2 >= 0,7)
- **Beschreibung:** Laut Teil C 6.4 wird nach |SRRC| geordnet, wenn R² der SRRC-Regression (auf Rängen) mindestens 0,7 beträgt, sonst nach s1_binned. sens_global() wendet das korrekt an (meta$r2_srrc, rank_by). Der Bericht sortiert aber mit r2_src (Regression auf Werten) neu und weicht damit von der Reihenfolge des Sensitivitätsobjekts ab.
- **Erwartet:** Reihenfolge wie im vofi_sensitivity-Objekt (rank_by = s1_binned, wenn r2_srrc < 0,7): x1, x3, x2.
- **Tatsächlich:** r2_src = 1,000 und r2_srrc = 0,679: Der Bericht ordnet nach |SRRC| und liefert x1, x2, x3.
- **Reproduktion:** Rscript /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/mcs/repro/repro_global_rank_r2.R /home/user/VoFi

### MCS-07 [minor] Globale Sensitivität von delta_vs_reference übergeht Eingaben, die nur in der Referenz vorkommen

- **Ort:** R/sensitivity.R:sens_global_result() (xx aus mc$inputs/mc$features des Variantenergebnisses)
- **Beschreibung:** Für ein Variantenergebnis aus vofi_compare() ist die Primärkennzahl delta_vs_reference. Als Eingaben dienen aber nur die Ziehungen der Variante. Schlüssel, die nur die Referenz hat, fehlen, obwohl sie über den Vereinigungsplan gezogen werden und die Differenz beeinflussen. In S4 ist das boiler_failure (Kesselausfall der Referenz; Tornado-Rang 11, Spearman mit delta_vs_reference −0,08).
- **Erwartet:** Eingaben aus der Vereinigung der Pläne von Variante und Referenz (CRN-Vereinigungsplan), also auch boiler_failure.
- **Tatsächlich:** vofi_sensitivity(cmp$results$v1_isfp_stufen, method = 'global'): kpi = delta_vs_reference, 'boiler_failure' %in% global$input ist FALSE.
- **Reproduktion:** Rscript /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/mcs/repro/repro_s4_report.R /home/user/VoFi  (Abschnitt F7)

### MCS-08 [minor] „In 10 von 10 simulierten Zukünften“ behauptet Sicherheit, wo es keine gibt

- **Ort:** R/report-html.R:rep_html_hh_risk_lines() und R/methods-mc.R:rep_mc_risk_lines() (count = round(10 * p))
- **Beschreibung:** Die Wahrscheinlichkeit wird mit round() auf Zehntel gerundet. Ab p = 0,95 heißt es „10 von 10“ (in jeder simulierten Zukunft besser), unter p = 0,05 „0 von 10“. Das ist für Nicht-Finanzleute eine Scheinsicherheit: Bei p = 0,951 ist die Variante in fast jedem zwanzigsten Lauf schlechter.
- **Erwartet:** Keine Aussage „10 von 10“ bzw. „0 von 10“, solange 0 < p < 1, z. B. „mehr als 9 von 10“ oder Prozent mit MC-Fehler (Memo 07 §5.4 Nr. 4, keine Scheingenauigkeit).
- **Tatsächlich:** p = 0,951 und 0,96 ergeben „In 10 von 10 simulierten Zukünften ist V1 besser als V0.“; p = 0,04 ergibt „In 0 von 10 …“.
- **Reproduktion:** Rscript /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/mcs/repro/repro_rounding_es05.R /home/user/VoFi

### MCS-09 [minor] es05 heißt bei Kennzahlen, bei denen kleiner besser ist, „Mittel der schlechtesten 5 %“, ist dort aber das Mittel der besten 5 %

- **Ort:** R/mc-stats.R:mc_stat_one() (es05 = mean(v[v <= q05]) für alle Kennzahlen); R/report-excel.R:rep_xl_sheet_mc_stats() mit Label excel_export es05
- **Beschreibung:** Das Excel-Blatt mc_stats weist es05 für alle Kennzahlen mit dem Kopf „Mittel der schlechtesten 5 %“ aus, ebenso p_neg als Nachteil. Bei Kennzahlen mit higher_is_better = FALSE (max_overdraft, max_financing_need, sum_equity_calls, own_contribution, monthly_burden_y1, payback_time) ist der untere Rand der günstige Rand. Die Spalte zeigt dort das Mittel der besten 5 %.
- **Erwartet:** Orientierung nach higher_is_better (bei FALSE das Mittel der Werte ≥ q95) oder ein neutrales Label wie „Mittel der kleinsten 5 %“.
- **Tatsächlich:** max_overdraft (higher_is_better = FALSE) mit Werten 0 … 60.000: es05 = 0 unter dem Kopf „Mittel der schlechtesten 5 %“, q95 = 46.500.
- **Reproduktion:** Rscript /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/mcs/repro/repro_rounding_es05.R /home/user/VoFi

### MCS-10 [minor] diff_stats ohne MC-Fehler für prob_better

- **Ort:** R/compare.R (Aufbau von diff_stats in cmp_assemble)
- **Beschreibung:** Teil C 6.3 verlangt für den Vergleich prob_better = mean(Δ > 0) mit einem Standardfehler wie bei p_neg (aus den Blockanteilen). diff_stats enthält nur die Spalten variant, kpi, mean, se, q05…q95 und prob_better. Für die wichtigste Vergleichsaussage gibt es damit keinen MC-Fehler, und Haushaltstext und Ampel nutzen p ohne Unsicherheitsangabe. Hinweis: Spec 00 §13.3 nennt die Spalte nicht, die Spezifikationen widersprechen sich hier.
- **Erwartet:** Spalte prob_better_se = sd(Blockanteile)/√R.
- **Tatsächlich:** Keine SE-Spalte. In S4 V1 steht nur prob_better = 0,995.
- **Reproduktion:** cmp <- vofi_compare(vofi_read_scenario(vofi_example('s4_efh_1975_isfp')), variants = 'v1_isfp_stufen', n_sim = 200, seed = 1); names(cmp$diff_stats)


## Eingabe, Berichte

### BA-01 [major] Haushalt: 'Gesamtersparnis' rechnet ohne Eigenanteil und widerspricht Gesamtkosten, Vermögensvergleich und Ampel

- **Ort:** R/report-views.R:rep_household_summary (item total_saving aus cumulative_saving) / rep_household_vs_ref
- **Beschreibung:** total_saving kumuliert nur die Differenz der monatlichen Belastung. Investitionen aus Eigenmitteln (Eigenanteil) fehlen darin. Bei Varianten mit sehr unterschiedlichem Eigenanteil kehrt sich dadurch das Vorzeichen um. Beispiel S4 v1_isfp_stufen: Der Bericht sagt 'Über 25 Jahre zahlen Sie gegenüber base insgesamt rund 70.100 € mehr'. In derselben Liste stehen aber Gesamtkosten von 253.500 € gegenüber 285.800 € bei base, also 32.300 € weniger. Dazu kommen ΔEW gegenüber der Referenz von +110.000 € (ohne Restwert +78.400 €), Ampel grün und 'In 10 von 10 simulierten Zukünften besser'. Memo 07 §5.4 definiert die Gesamtkosten als 'Summe aller variantenabhängigen Auszahlungen abzüglich Zuschüsse'; die Gesamtersparnis muss darauf beruhen. Die Abweichung entspricht genau der Eigenanteil-Differenz (172.600 − 70.100 = 102.500; −70.100 + 102.500 ≈ +32.300).
- **Erwartet:** Gesamtersparnis = Gesamtkosten(Referenz) − Gesamtkosten(Variante), also inklusive Eigenanteil und Zuschüssen. Für S4 v1 ergibt das rund 32.300 € Ersparnis, für v2 rund 65.500 € statt 50.200 €.
- **Tatsächlich:** S4 v1: 'zahlen insgesamt rund 70.100 € mehr' (−70.135). Daneben 'Über 25 Jahre zahlen Sie insgesamt rund 253.500 €', bei base 285.800 €, und Ampel grün.
- **Reproduktion:** cmp4 <- vofi_compare(vofi_read_scenario(vofi_example('s4_efh_1975_isfp'))); s <- attr(vofi_household_view(cmp4),'summary'); s[s$item %in% c('total_saving','total_cost','own_contribution'), c('variant','item','value','text')]  # vgl. /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/ba/repro_findings.R (F03)

### BA-02 [major] Selbstnutzer: 'Zusätzlich sind Nachschüsse von rund 983.200 € nötig': die Nachschüsse sind die Monatsbelastung selbst (Doppelzählung)

- **Ort:** R/report-views.R:rep_household_summary (item equity_calls), Label report.household.text.equity_calls, Glossar report.html.household.glossary Nachschüsse
- **Beschreibung:** Der Selbstnutzer-VoFi hat kein Einkommen. Jede laufende Belastung (Zinsen, Tilgung, Energie, Wartung) wird deshalb als endogener Nachschuss gebucht. In S5 v2 sind 2028 die Nachschüsse 29.661 € = 2.471,79 € × 12, also genau die Monatsbelastung. Der Bericht nennt die Monatsbelastung (2.470 €), den Eigenanteil (180.000 €) und dann 'Zusätzlich sind Nachschüsse von insgesamt rund 983.200 € nötig'. Das Glossar erklärt Nachschüsse als 'Geld, das Sie später zusätzlich einzahlen müssen'. Ein Haushalt liest daraus einen weiteren Finanzbedarf von knapp 1 Mio. €, der in Wahrheit die Summe der schon genannten Monatsraten ist. Gleiches gilt für die Tabelle 'Summe der Nachschüsse 967.400 / 983.200 / 1.020.200 / 980.100 €'.
- **Erwartet:** Für Selbstnutzer die durch die Monatsbelastung gedeckten Fehlbeträge nicht als 'zusätzliche Nachschüsse' ausweisen. Nur Fehlbeträge über die Belastung bzw. Sparfähigkeit hinaus nennen, oder klar sagen, dass sie aus dem laufenden Einkommen bezahlt werden.
- **Tatsächlich:** S5 v2_eh40_kfw300: Summe Belastung (ohne bisherige Miete) 1.020.982 €, Summe Nachschüsse 983.235 €, Text 'Zusätzlich sind Nachschüsse von insgesamt rund 983.200 € nötig.'
- **Reproduktion:** cmp5 <- vofi_compare(vofi_read_scenario(vofi_example('s5_neubau_efh_eh40'))); hv <- vofi_household_view(cmp5,'v2_eh40_kfw300'); c(sum((hv$burden-hv$current_rent)*hv$months), sum(hv$equity_calls)); attr(hv,'summary')$text[9]  # F06

### BA-03 [major] Warmmietenänderung 'erstes volles Jahr' ist das Baujahr vor Umlagebeginn; Restriktion Warmmiete und Ampel übersehen einen Anstieg um +0,95 €/m²

- **Ort:** R/kpi-realestate.R:kpi_series_y1 / warm_rent_change_prepost_y1, restriction_warm_rent; Ausweis in report-html.R (Summary, Restriktionen)
- **Beschreibung:** Bei Bestandsprojekten mit construction_months = 0 gilt das Maßnahmenjahr als erstes volles Betriebsjahr. In S1 werden die Maßnahmen am 01.10.2027 fertig, die Umlage wirkt ab 2028. KPI und Restriktion messen also 2027 (keine Umlage, nur ein Quartal mit niedrigeren Heizkosten). Der Bericht meldet 'Warmmietenänderung vorher/nachher −0,24 €/m²' und 'gegenüber base −0,20 €'. Die Mietertabelle zeigt ab 2028 dagegen +0,05 (vorher/nachher) bzw. +0,31 (gegenüber Referenz). Gegenprobe S1 ohne freiwillige Kappung (voluntary_cap_per_m2 entfernt): ab 2028 +0,95 €/m² vorher/nachher und +1,21 gegenüber Referenz, also deutlich über der Schwelle von 0,50. Trotzdem restriction_warm_rent = 0, Restriktion 'nein' und kein K.-o. In S3 haben v2_wp_pv (§ 559e) und v2_jaz_test identische −0,14, weil die unterschiedliche Umlage nicht ins Jahr 2027 fällt.
- **Erwartet:** Warmmietenänderung und Restriktion beziehen sich auf das erste volle Jahr nach Fertigstellung bzw. nach Wirksamwerden der Umlage, alternativ auf das Maximum über die Betriebsjahre. Die Kopfzahl darf der Mietertabelle nicht widersprechen.
- **Tatsächlich:** Uncapped S1: change_prepost 2027 −0,24 / 2028 +0,95, KPI warm_rent_change_prepost_y1 = −0,238, restriction_warm_rent = 0, Ampel ohne K.-o.
- **Reproduktion:** sc <- vofi_read_scenario(vofi_example('s1_wu_mfh_1963_eh70')); sc$variants$v2_eh70$set[['unit_groups.bestand.rent_law.voluntary_cap_per_m2']] <- NULL; cmp <- vofi_compare(sc); vofi_tenant_view(cmp,'v2_eh70')[1:3,c('year','levy','change_prepost','change_vs_reference')]; cmp$kpi_table[cmp$kpi_table$variant=='v2_eh70' & cmp$kpi_table$kpi %in% c('warm_rent_change_prepost_y1','restriction_warm_rent'),]  # F02

### BA-04 [major] Vergleichsbericht: 'wichtigste Einflussgrößen', 'Die wichtigsten Risiken' (Kurzvorlage) und Haushalts-Verteilungsgrafik stammen aus der Referenzvariante gegen die Unterlassung

- **Ort:** R/report-html.R:rep_html_context (mc <- Referenz des Vergleichs), rep_html_drivers, rep_html_risk_household (vofi_plot(rc$mc,'verteilung')), Kurzvorlage risks
- **Beschreibung:** Im Vergleich setzt rep_html_context base = rep_comparison_result(cmp, NULL), also die Referenz, und mc = deren Simulation. rep_html_drivers rangiert deshalb die Spearman-Korrelationen der Primärkennzahl der Referenz. Bei Bestandsprojekten ist das delta_terminal_value, das 'Bestandszahlungen enthält', nicht die Entscheidungskennzahl delta_vs_reference. S4: Der Bericht nennt 'Habenzins, energy_price_gas.growth, Wachstum Gasnetzentgelte'. Die echten Treiber von delta_vs_reference für v1 sind BAFA-Zusage 2033 (|ρ| = 0,66), Baupreisabweichung (0,46) und Zins KfW 358 (0,25). Für v2 sind es Gaspreistrend, Gasnetzentgelte und WP-Strompreis. S1: Bericht 'Mietsteigerung, Baupreisindex, Leerstand', echt 'Mietsteigerung, Kostenabweichung EH-70, Kostenabweichung Ohnehin'. Im Haushaltsbericht 'Wie sicher ist das Ergebnis?' folgt direkt auf 'In 10 von 10 Zukünften ist v1 besser als base' das Histogramm der Referenz mit 'Anteil > 0: 0,00 %; Basisfall −356.002 €'.
- **Erwartet:** Treiber, Risiken und Verteilungsgrafik im Vergleich aus den Differenzen je Lauf (cmp$differences$delta_vs_reference, je Variante bzw. für die beste Variante), passend zur Ampel.
- **Tatsächlich:** Treiber und Grafik der Referenz gegen die Unterlassung; Kurzvorlage S1 'Die wichtigsten Risiken: 1. Mietsteigerung § 558 2. Abweichung Baupreisindex 3. Leerstand'.
- **Reproduktion:** siehe /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/ba/repro_findings.R Abschnitt F08: rc <- rep_html_context(list(main=cmp4m,...),'household',...); identical(rc$mc, cmp4m$results$base) -> TRUE; rep_mc_primary(rc$mc)$kpi -> 'delta_terminal_value'; Spearman von cmp4m$differences$delta_vs_reference gegen inputs liefert andere Top 3

### BA-05 [major] EUR/m²/Monat (und andere Nicht-EUR-Einheiten) in KPI-Tabellen ganzzahlig gerundet ('Warmmiete 10', 'Änderung 0') und damit im Widerspruch zum Text (−0,24 / −0,20)

- **Ort:** R/methods-misc.R:rep_fmt_value (digits gilt im default-Zweig auch für EUR_m2_month, EUR_t, EUR_month); Aufrufer mit digits = 0: methods-compare.R:87,108 (rep_cmp_kpi_matrix, rep_cmp_diff_matrix), methods-mc.R:84, report-html.R:1501,1635,2396,2593,2774
- **Beschreibung:** Die Kennzahlentabellen formatieren mit digits = 0, wie es für € gedacht ist. Dieser Wert gilt aber auch für EUR_m2_month. Folge in S1 (print und HTML-Fach- und Kurzbericht, auch Excel-unabhängige Konsolen-Prints): 'Warmmiete (erstes volles Jahr) 10 EUR/m²/Monat' (10,43), 'Warmmietenänderung vorher/nachher 0 EUR/m²/Monat' (−0,24), 'Warmmietenänderung gegenüber der Referenz 0 EUR/m²/Monat' (−0,20) mit 'P(besser) 100,0 %'. In der MC-Statistik stehen P5 bis P95 alle bei '0 EUR/m²/Monat' neben 'P(< 0) 100,0 %'. Derselbe Bericht schreibt im Text '−0,24 EUR/m²/Monat' und '−0,20 € je m²', in der Kopftabelle des Einzelberichts aber '0 EUR/m²/Monat' über einer Jahresreihe mit −0,04. Betroffen sind auch S2 (15 €/m²) und S3 (9 €/m²) sowie die Zielwerte der Zielwertsuche (target mit 0 Stellen).
- **Erwartet:** €/m²/Monat immer mit 2 Nachkommastellen (Konzept: €/m²·Monat; Aufgabenstellung). Die Rundung je Einheit gehört in rep_fmt_value, nicht in den Aufrufer.
- **Tatsächlich:** rep_fmt_value(-0.2381912, 'EUR_m2_month', 0) liefert '0 EUR/m²/Monat'; print(vofi_compare(S1)) zeigt 'Warmmiete 10 EUR/m²/Monat'.
- **Reproduktion:** cmp1 <- vofi_compare(vofi_read_scenario(vofi_example('s1_wu_mfh_1963_eh70'))); print(cmp1); vofi:::rep_fmt_value(-0.2381912,'EUR_m2_month',0)  # F01

### BA-06 [major] Amortisationsjahr: Haushaltstabelle (vs. Unterlassung) widerspricht dem Klartext (vs. Referenz); Kleinvermieter 'Amortisationsjahr 2027' neben 'nicht bezahlt gemacht'

- **Ort:** R/report-html.R:rep_html_variants_household (keys payback_year) vs. R/report-views.R:rep_household_summary (payback gegen Referenz)
- **Beschreibung:** Die Tabelle 'Ihre Varianten im Vergleich' zeigt die Kennzahl payback_year (gegen die Unterlassung, laut 12.3a im Bestand nicht lesbar). Die Klartexte darunter verwenden die Vermögensdifferenz gegen die Referenzvariante. S4 und S5: Tabelle 'Amortisationsjahr n. d.' für alle Varianten, Text 'hat sich voraussichtlich 2027 bzw. 2056 bezahlt gemacht'. Kleinvermieter (S3 mit perspective = kleinvermieter): Tabelle 'Amortisationsjahr 2027 / 2027 / 2027' (auch für die Referenz), Text 'Bis zum Horizontende … nicht bezahlt gemacht'.
- **Erwartet:** Die Tabelle zeigt payback_year_vs_reference (Haushalt: Vermögensamortisation gegen die Referenz) und keinen Wert für die Referenz selbst; Tabelle und Text stimmen überein.
- **Tatsächlich:** Widersprüchliche Amortisationsaussagen im selben Abschnitt.
- **Reproduktion:** sc3 <- vofi_read_scenario(vofi_example('s3_eg_waermepumpe_pv')); sc3$project$perspective <- 'kleinvermieter'; sc3$project$report_mode <- 'household'; sc3$unit_groups$mitglieder$rent_regime <- 'paragraph_558'; vofi_report(vofi_compare(sc3), 'kv.html', open=FALSE)  # Tabelle 'Amortisationsjahr 2027' vs. Text 'nicht bezahlt gemacht' (F11)

### BA-07 [major] 'Die Investition hat sich 2027 bezahlt gemacht' im Investitionsjahr; Zeitwert-Pfad macht jede geförderte Maßnahme sofort 'amortisiert'

- **Ort:** R/report-views.R:rep_household_summary (payback aus wealth_diff_vs_reference mit rv_basis measures), Label report.household.text.payback
- **Beschreibung:** Die Haushalts-Amortisation nutzt W_t = BS_t + Zeitwert der Maßnahmen. Am Jahresende des Investitionsjahres ist der Zeitwert fast gleich den Kosten. Mit Zuschüssen ist die Differenz deshalb sofort ≥ 0. S4: v1 und v2 'haben sich voraussichtlich 2027 bezahlt gemacht' (payback_vs_reference = 0,0 Jahre in allen 1.000 Läufen). Ohne Restwert liegt die Amortisation bei 23 Jahren (v1, 2049/2050) bzw. 4 Jahren (v2). Memo 07 §5.4 nennt im Formulierungsmuster für genau diesen Fall 'nach etwa vier bis fünf Jahren bezahlt gemacht', also die Liquiditäts- bzw. Vermögenssicht ohne Zeitwert. Dieselbe Aussage steht neben 'zahlen insgesamt 70.100 € mehr' (BA-01) und Ampel grün. Für einen Haushalt ist das irreführend, auch wenn die Basis in Klammern genannt wird.
- **Erwartet:** Im Haushaltsmodus mindestens zusätzlich die Amortisation ohne Restwert ('nur Guthaben und Schulden') nennen bzw. vorrangig zeigen. Keine Aussage 'bezahlt gemacht' im Jahr der Investition ohne Hinweis, dass dies nur am angesetzten Zeitwert liegt.
- **Tatsächlich:** S4 v1/v2: 'Die Investition hat sich voraussichtlich 2027 bezahlt gemacht (Vermögensvergleich mit dem Zeitwert der Maßnahmen).' Ohne Restwert: 2050 (v1) bzw. 2031 (v2).
- **Reproduktion:** cmp4 <- vofi_compare(vofi_read_scenario(vofi_example('s4_efh_1975_isfp'))); s <- attr(vofi_household_view(cmp4),'summary'); s$text[s$item=='payback_year']; cmp4$kpi_table[cmp4$kpi_table$kpi %in% c('payback_vs_reference','payback_vs_reference_ex_rv'),]

### BA-08 [major] Kleinvermieter: Cashflow-Änderung mit Spar-Vokabular, '940 € mehr' bedeutet 940 € weniger Überschuss

- **Ort:** R/report-html.R:rep_html_hh_fmt (monthly_cashflow_change -> rep_html_hh_diff_text), Burden-Tabelle Zeile 3247-3248 (cashflow_change)
- **Beschreibung:** rep_html_hh_diff_text ist für Kosten gedacht: positiv heißt 'spart', negativ heißt '… € mehr'. Auf die Cashflow-Änderung (positiv = mehr Überschuss) angewendet, kehrt sich die Bedeutung um. Bei −943 €/Monat steht in der Spalte 'Änderung gegenüber Referenz' '940 € mehr', bei +800 € 'spart 800 €'. Der Klartext darüber sagt richtig 'bleibt Ihnen rund 940 € pro Monat weniger'. Tabelle und Text widersprechen sich.
- **Erwartet:** Für Cashflow-Änderungen 'Überschuss + … €' bzw. '… € weniger Überschuss' oder 'mehr/weniger Überschuss'.
- **Tatsächlich:** vofi:::rep_html_hh_diff_text(-943.5) liefert '940 € mehr'; Kleinvermieter-Bericht Tabelle 2027: 'Überschuss 3.890 € | 940 € mehr'.
- **Reproduktion:** vofi:::rep_html_hh_diff_text(-943.5); Bericht wie BA-06 (F11 in repro_findings.R)

### BA-09 [major] Rohe technische Schlüssel und unaufgelöste Referenzen in Haushalts- und Fachberichten

- **Ort:** R/report-html.R:rep_html_input_label (keine Auflösung von '<prozess>.<param>'), rep_sens_param_labels, Annahmen-Tabelle Haushalt, rep_html_condition_label, Variantennamen überall; Excel-Blatt 'Ampel'
- **Beschreibung:** (1) Treiber: 'energy_price_gas.growth', 'inflation.mu', 'energy_price_power.growth' (S3, S4, S5), obwohl der Prozess das Label 'Erdgaspreis EFH (ohne CO2, ohne Netzentgelt)' hat. rep_html_input_label sucht nur den vollen Schlüssel. Gleiches gilt für den Tornado-Pfad. (2) Die Haushalts-Annahmentabelle zeigt statt Werten 'Habenzins ref: market.mortgage_rate', 'Sollzins Kontokorrent ref: market.mortgage_rate' und 'Zins ref: funding.kfw358_2030.loan.variants.v25_3_10.rate_pa'. Der Zins der KfW-Kredite und der Habenzins (S5!) sind damit für den Haushalt nicht ablesbar. (3) Varianten erscheinen nur als Schlüssel ('Gegenüber base sparen Sie …', 'Variante v1_isfp_stufen'), obwohl Labels vorhanden sind ('V1 iSFP stufenweise …'). (4) Förderzeilen zeigen 'kfw458_wp: Investitionszuschuss wp_2027 (458)' und 'beg_em_huelle'; offene Prüfpunkte 'wpb_definition', 'building_permit' (kein Label unter expand.funding.conditions). (5) Excel-Blatt Ampel: Grundlage 'mc', Spaltenkopf 'notes', TRUE/FALSE.
- **Erwartet:** Labels statt Schlüssel (Prozesslabel + Parameter, z. B. 'Erdgaspreis EFH: Trend'), aufgelöste Werte (Basisfallwert) statt 'ref: …', Variantenlabels.
- **Tatsächlich:** siehe Beschreibung; S4-MC-Haushaltsbericht: 'Am stärksten hängt das Ergebnis von Habenzins, energy_price_gas.growth und Wachstum Gasnetzentgelte p. a. ab.'
- **Reproduktion:** cmp4m <- vofi_compare(vofi_read_scenario(vofi_example('s4_efh_1975_isfp')), n_sim=200, seed=42); vofi_report(cmp4m,'s4.html',open=FALSE); dann im Text nach 'energy_price_gas.growth' und 'ref: ' suchen (F08 in repro_findings.R)

### BA-10 [major] Kurzvorlage 'Mittelherkunft': Summe ≠ Investition und Tilgungszuschuss doppelt als 'Zuschüsse' gezählt

- **Ort:** R/report-html.R:rep_html_sources / rep_html_sec_investment
- **Beschreibung:** Die Zeile 'Investition' summiert alle Investitions- und Ersatzauszahlungen über den Horizont. Die Quellen zeigen nur die Anfangsfinanzierung. Der Tilgungszuschuss wird über rep_html_funding_total zusätzlich zum Kreditbetrag als 'Zuschüsse' geführt, obwohl er den Kredit tilgt und keine weiteren Mittel bringt. S1 base: Investition 884.105 € gegen Quellen 578.673 €. S1 v2: Investition 1.871.657 € gegen EK 151.488 + kfw261 1.300.000 + 'Zuschüsse' 144.400 = 1.595.888 €. Der Fachbericht sagt im Abschnitt 5.2.2 für dieselbe Variante 'Keine Zuschüsse eingerechnet'. Einer Gremienvorlage fehlt damit eine stimmige Mittelverwendung/-herkunft.
- **Erwartet:** Gleiche Basis für Investition und Quellen (z. B. Anfangsinvestition gegen Anfangsfinanzierung, Ersatzinvestitionen 'aus laufenden Überschüssen' separat). Tilgungszuschuss nur als Merkposten bzw. als Kreditminderung, nicht als zusätzliche Quelle.
- **Tatsächlich:** Tabelle 'Mittelherkunft' summiert sich nicht und widerspricht Abschnitt 5.2.2.
- **Reproduktion:** cmp1 <- vofi_compare(vofi_read_scenario(vofi_example('s1_wu_mfh_1963_eh70'))); s <- vofi:::rep_html_sources(vofi:::rep_det_result(cmp1$results$v2_eh70)); data.frame(s$labels, s$values); s$invest  # F13

### BA-11 [major] Energie- und CO2-Abschnitt im Vergleichsbericht zeigt nur die Referenz, unbeschriftet; Pflichtinhalte fehlen

- **Ort:** R/report-html.R:rep_html_sec_energy (verwendet rc$res = Referenz)
- **Beschreibung:** Im Vergleich ist rc$res das Ergebnis der Referenz. Der Abschnitt 'Energie und CO2' zeigt Energiekosten, CO2-Kosten und CO2-Emissionen nur von base, ohne Variantenangabe. In S1 sind das z. B. 'Energiekosten −888 €, CO2-Kosten −1.479 €, CO₂-Emissionen 1.662,0 t CO2'. Zur bewerteten Variante gibt es nur die CO2-Minderung. Es fehlen außerdem Verbrauch je Energieträger, CO2 in t/a (nur Horizontsumme), der Vermieteranteil CO2KostAufG/§ 5a getrennt und die CO2-Vermeidungskosten: Diese stehen in der kpi_table (−604 €/t), werden aber nur aus cmp$differences gelesen, das sie nicht enthält.
- **Erwartet:** Je Variante Energiekosten, Verbrauch je Träger, CO2 t/a, Vermieteranteil und CO2-Vermeidungskosten (Memo 07 §5.1 Nr. 6).
- **Tatsächlich:** Nur Referenzwerte ohne Kennzeichnung; Vermeidungskosten fehlen.
- **Reproduktion:** vofi_report(vofi_compare(vofi_read_scenario(vofi_example('s1_wu_mfh_1963_eh70'))), 's1.html', open=FALSE); Abschnitt 7 lesen

### BA-12 [minor] 'Rate im ersten vollen Jahr rund 0 €' für später ausgezahlte Kredite

- **Ort:** R/report-html.R:rep_html_instruments (rate_y1 = erstes volles Betriebsjahr des Projekts)
- **Beschreibung:** rate_y1 nimmt das erste volle Betriebsjahr des Projekts, nicht das erste volle Jahr nach Auszahlung des Kredits. S4 v1: 'kfw358_2030: Kreditbetrag rund 70.000 €, Rate im ersten vollen Jahr rund 0 € pro Monat'. Die Belastungstabelle zeigt ab 2030 Zinsen von 150 €/Monat, ab 2036 Zins und Tilgung von 580 €/Monat.
- **Erwartet:** Rate im ersten vollen Jahr nach Auszahlung (und je Phase: tilgungsfrei / Annuität, Memo 07 §5.2 e 'Raten je Phase').
- **Tatsächlich:** rate_y1 = 0 für kfw358_2030 und kfw358_2033.
- **Reproduktion:** cmp4 <- vofi_compare(vofi_read_scenario(vofi_example('s4_efh_1975_isfp'))); vofi:::rep_html_instruments(vofi:::rep_det_result(cmp4$results$v1_isfp_stufen))[,c('label','draw','rate_y1')]  # F07

### BA-13 [minor] Haushalt 'In der Rechnung ist keine Förderung enthalten' trotz KfW-300/297-Förderkredit; Förderbetrag im Vergleich ohne Variantenbezug

- **Ort:** R/report-html.R:rep_html_summary_household / rep_html_funding_total, Label report.html.household.no_grants
- **Beschreibung:** rep_html_funding_total zählt nur Zuschüsse und Tilgungszuschüsse. Für S5 'EH 40 mit KfW 300' (1,00 % statt 4,10 % Bankzins) steht 'In der Rechnung ist keine Förderung enthalten', ebenso bei jeder Variante unter 'Förderung und Kredite'. Im S4-Vergleich bezieht sich 'Sie erhalten Förderung von insgesamt rund 35.800 €' still auf die beste Variante v1; v2 erhält nur 15.700 €.
- **Erwartet:** 'keine Zuschüsse' statt 'keine Förderung' bzw. Förderkredite nennen (mit Zinsvorteil); Förderbetrag je Variante.
- **Tatsächlich:** siehe Beschreibung
- **Reproduktion:** vofi_report(vofi_compare(vofi_read_scenario(vofi_example('s5_neubau_efh_eh40'))), 's5.html', open=FALSE)

### BA-14 [minor] Risiko 'in einfachen Worten': Bandbreiten-Zeilen ohne Variantenbezug, Bandbreite der Belastung statt des Ergebnisses, entartete Spannen und '10 von 10'

- **Ort:** R/report-html.R:rep_html_risk_household, rep_html_hh_risk_lines; R/report-views.R:rep_household_range
- **Beschreibung:** Im Risikoabschnitt stehen 3 bzw. 4 Zeilen 'Voraussichtlich rund 300 € / 190 € / 190 € pro Monat; in 8 von 10 … zwischen 300 € und 300 €' ohne Angabe von Variante und Größe (es ist die Monatsbelastung im Jahr 1 inklusive Referenz). Memo 07 §5.4 Nr. 3 meint die Bandbreite des Ergebnisses (Ersparnis). Durch die 10-€-Rundung entstehen entartete Spannen ('zwischen 190 € und 190 €') bzw. Median gleich Obergrenze ('rund 190; zwischen 180 und 190'). 'In 10 von 10 simulierten Zukünften ist v1 besser' bei P = 99,6 % (alles ab 95 % wird zu 10 von 10, alles unter 5 % zu 0 von 10) behauptet Sicherheit.
- **Erwartet:** Bandbreite der Ersparnis je benannter Variante; bei sehr hohen bzw. niedrigen Anteilen 'in fast allen' bzw. 'in weniger als 1 von 10'; entartete Spannen zusammenfassen.
- **Tatsächlich:** siehe Beschreibung (S4/S5 MC-Haushaltsberichte)
- **Reproduktion:** F08 in /tmp/claude-0/-home-user-VoFi/6a2d58c1-9387-5263-9942-e149585d85ae/scratchpad/ba/repro_findings.R (grep 'simulierten')

### BA-15 [minor] Ampel-Hinweis wird an '; ' zerschnitten: '(Schwelle 40,0 %' / 'Wahrscheinlichkeit -)'

- **Ort:** R/report-html.R:727 rep_html_cmp_tl (strsplit(notes, '; ')) und Label mc.traffic_light.ko_* mit '; ' im Text
- **Beschreibung:** Die Ampel-Hinweise sind mit '; ' verbunden. Die K.-o.-Texte enthalten selbst '(Schwelle {threshold}; Wahrscheinlichkeit {prob})'. Der Bericht zeigt deshalb zwei kaputte Aufzählungspunkte: '…Belastungsquote 40,4 % im Jahr 2032 (Schwelle 40,0 %' und 'Wahrscheinlichkeit -)'. Betroffen sind S2 (DSCR) und S5 (Belastung), jeweils deterministisch und MC.
- **Erwartet:** Hinweise als Vektor speichern oder einen eindeutigen Trenner verwenden.
- **Tatsächlich:** rep_html_cmp_tl(cmp5,'v2_eh40_kfw300')$notes[4:5]
- **Reproduktion:** cmp5 <- vofi_compare(vofi_read_scenario(vofi_example('s5_neubau_efh_eh40'))); vofi:::rep_html_cmp_tl(cmp5,'v2_eh40_kfw300')$notes  # F12

### BA-16 [minor] Basisfall-Abschnitte zeigen 'Wahrscheinlichkeit besser als Referenz 100,00 %' (auch im MC-Bericht mit 90,70 %); Konsolen-Print zeigt P5/Median/P95/P(besser) für deterministische Vergleiche

- **Ort:** R/report-html.R:rep_html_kpi_tables / Variantenvergleichstabelle (prob_better_than_ref deterministisch 0/1); R/methods-compare.R:print (rep_cmp_diff_matrix)
- **Beschreibung:** Der deterministische Fachbericht S1 schreibt 'Ohne Monte-Carlo-Simulation gibt es keine Wahrscheinlichkeit „besser als die Referenz“'. In Tabellen desselben Berichts steht 'Wahrscheinlichkeit besser als Referenz 100,00 %'. Im MC-Bericht zeigt Abschnitt 3 (Basisfall) 100,00 % bzw. bei S2 0,00 %, während Summary und Risiko 90,70 % bzw. 19,70 % angeben. print(vofi_compare(...)) ohne Simulation gibt P5 = Median = P95 und 'P(besser) 100,0 % / 0,0 %' aus, was Konzept 4.7 als Scheingenauigkeit ausschließt.
- **Erwartet:** prob_better_than_ref in Basisfall-Tabellen weglassen bzw. 'n. d. (nur Simulation)'; im deterministischen Print nur den Basisfallwert.
- **Tatsächlich:** siehe Beschreibung
- **Reproduktion:** cmp1 <- vofi_compare(vofi_read_scenario(vofi_example('s1_wu_mfh_1963_eh70'))); print(cmp1); vofi_report(cmp1,'s1.html',open=FALSE)  # F15

### BA-17 [minor] Amortisationsdauer/-jahr gegen die Unterlassung im Bestand ohne Vermerk ('0,0 Jahre', 'Amortisation 2027')

- **Ort:** R/methods-compare.R:print, R/report-html.R:rep_html_cmp_head_kpis / rep_html_kpi_tables, R/report-plot.R:rep_plot_wealth_diff (Untertitel)
- **Beschreibung:** Spec 12.3a sagt ausdrücklich, dass ΔEW und payback_time gegen die Unterlassung im Bestand nicht als Vorteilhaftigkeit lesbar sind. ΔEW trägt den Vermerk, die Amortisation nicht. Gezeigt werden S1 'Amortisationsdauer 0,0 Jahre' (base und v2), 'Amortisationsjahr 2027', S3 '1,0 Jahre', der Einzel-Print S1 'Amortisationsjahr 2027' und der Grafik-Untertitel 'Amortisation 2027' zur Vermögensdifferenz gegen die Unterlassung. In der Kurzvorlage S1 steht die Amortisationsdauer gleich unter den Primärkennzahlen.
- **Erwartet:** Vermerk 'enthält Bestandszahlungen' auch für payback_* bzw. Ausweis nur gegen die Referenz.
- **Tatsächlich:** siehe Beschreibung
- **Reproduktion:** print(vofi_run(vofi_build(vofi_read_scenario(vofi_example('s1_wu_mfh_1963_eh70')))))

### BA-18 [minor] Excel-Export Vergleich: Annahmenblatt nur der Referenz; MC-Vergleich ohne Läufe und MC-Statistik

- **Ort:** R/report-excel.R:rep_xl_sheet_assumptions (nur rep_comparison_result(x)), rep_xl_codes für vofi_comparison
- **Beschreibung:** Das Blatt 'Annahmen' eines Vergleichs enthält nur die Herkunft der Referenz (Variante 'base'). In S1 kommt kfw261 (1,3 Mio. € Förderkredit) 0-mal vor, ebenso die Variantenmaßnahmen. Der HTML-Bericht zeigt immerhin die Overlay-Diffs. Beim MC-Vergleich fehlen die Blätter 'Kennzahlen je Lauf' (z. B. delta_vs_reference je Lauf) und 'MC-Statistik' je Variante. P(besser) lässt sich in Excel daher nicht nachrechnen (Konzept 5.5: 'bei Simulation zusätzlich MC-Statistik, Kennzahlen je Lauf …; bei Vergleich die Varianten').
- **Erwartet:** Annahmen je Variante (oder Overlay-Diff); bei MC-Vergleichen Differenzen je Lauf und MC-Statistik.
- **Tatsächlich:** siehe Beschreibung
- **Reproduktion:** vofi_export_excel(vofi_compare(vofi_read_scenario(vofi_example('s1_wu_mfh_1963_eh70'))), 's1.xlsx'); a <- openxlsx::read.xlsx('s1.xlsx', sheet='Annahmen', colNames=FALSE); sum(apply(a,1,function(r) any(grepl('kfw261',r))))  # 0 (F14)

### BA-19 [minor] Pflichtbestandteile laut Konzept/Memo 07 fehlen im Bericht (DSCR/LTV je Jahr, Differenzvermögen gegen Referenz, Haushaltsgrafiken, Kaufkraftsicht, Genossenschaft/Mitglieder)

- **Ort:** R/report-html.R:rep_html_financing_blocks (rep_html_series_table(c('dscr','icr','ltv','lending_ratio'))), rep_html_sec_timeline, Haushaltsabschnitte
- **Beschreibung:** (1) Die Tabelle 'DSCR und LTV je Jahr' wird nie ausgegeben: Sie sucht kpi_series dscr/icr/ltv, es gibt aber nur die Reihen-KPIs warm_rent, warm_rent_change_prepost und monthly_burden (toter Code; Pflichttabelle Persona a). (2) Im Vergleich fehlt die Grafik 'Differenzvermögen Variante − Referenz mit Amortisationsmarke' (Memo 5.3, Pflichtgrafik a). Sie ist im Bestand die einzig lesbare Amortisationsgrafik. (3) Der Haushaltsbericht enthält nur 2 Grafiken (Belastung, Verteilung der Referenz). Es fehlen kumulierte Ersparnis, Zeitstrahl der Stufen (d), Restschuldverlauf, 'Fächer Rate nach 2037' (e) und 'einfacher Fächer' (5.1 Nr. 7). (4) Keine umschaltbare Sicht 'in heutiger Kaufkraft' (Konzept 1.4, Memo 5.4 Nr. 6). (5) Keine Seite 'Genossenschaft / Mitglieder' (Memo 5.2 b). (6) 'Was passiert, wenn …' nur Restwert, Habenzins und 2045-Stufe, ohne Gaspreis, Förderstopp und Kesselausfall (Memo 5.2 d). (7) Kennzahlen je WE/m² fehlen für Investition, Förderung, Mehrinvestition, Kapitaldienst und Umlage (Konzept 1.4).
- **Erwartet:** Abschnitte bzw. Grafiken laut Memo 07 §5.1 bis 5.3 und Konzept 1.4/5.5.
- **Tatsächlich:** fehlen
- **Reproduktion:** vofi_report(vofi_compare(vofi_read_scenario(vofi_example('s4_efh_1975_isfp')), n_sim=200, seed=1), 's4.html', open=FALSE); vofi_run(vofi_build(vofi_read_scenario(vofi_example('s1_wu_mfh_1963_eh70'))))$kpi_series |> names()

### BA-20 [minor] Haushaltstabelle mischt MC-Mittelwerte (unbeschriftet) mit Basisfall-Texten

- **Ort:** R/report-html.R:rep_html_variants_household (rep_cmp_value = Mittel über Läufe)
- **Beschreibung:** Im MC-Vergleich zeigt 'Ihre Varianten im Vergleich' Mittelwerte über die Läufe ohne Hinweis darauf: Eigenanteil base 164.600 €, v1 87.900 €, Belastungsquote base 8 %. Die Klartexte direkt darüber und darunter nennen Basisfallwerte: Eigenanteil 172.600 € / 70.100 €, Belastungsquote 7 %. Für den Haushalt sind das widersprüchliche Zahlen.
- **Erwartet:** Einheitlich Basisfall oder klar als 'Mittel der Simulation' kennzeichnen.
- **Tatsächlich:** siehe Beschreibung (S4 MC-Haushaltsbericht)
- **Reproduktion:** vofi_report(vofi_compare(vofi_read_scenario(vofi_example('s4_efh_1975_isfp')), n_sim=1000, seed=42), 's4.html', open=FALSE)

### BA-21 [minor] Sprach- und Plausibilitätsmängel in Haushaltstexten

- **Ort:** inst/labels/de/report.yaml (household.text.*, funding_check.status_open, plot.title_cmp_diff); report-views.R:rep_household_summary
- **Beschreibung:** Mängel: '40 % … Das liegt über der Schwelle von 40 %' (40,4 % auf ganze Prozent gerundet); 'Über 29 Jahre …', obwohl Summe und Ersparnis die Bauphase einschließen (30 Jahre); 'Eigenanteil nach Förderung (Einmalbetrag) 172.600 €' für 'Gaskessel behalten', tatsächlich die Summe der Ohnehin-Maßnahmen 2028–2050; '1 offene Prüfpunkte'; Grafiktitel 'Endwertdifferenz gegenüber der Referenz gegenüber base'; im Einzel-MC Bestand 'In 0 von 10 simulierten Zukünften ist die Endwertdifferenz positiv' ohne Bestandszahlungs-Vermerk.
- **Erwartet:** Konsistente Rundung bei Schwellen (z. B. 1 Nachkommastelle), korrekte Jahreszahl, 'Investitionen aus Eigenmitteln über den Zeitraum' statt 'Einmalbetrag', korrekte Numerus-Formen.
- **Tatsächlich:** siehe Beschreibung
- **Reproduktion:** Berichte S4/S5 (Haushalt) wie oben
