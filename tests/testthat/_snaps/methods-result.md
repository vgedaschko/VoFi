# Snapshots von print() und summary() (13.6, 15.6)

    Code
      print(x)
    Output
      VoFi-Ergebnis: testkit (oracle_a), Variante base
      Deterministischer Lauf, Stichtag 01.01.2027, Horizontende 01.01.2032 (T = 5)
      Perspektive: Privates Wohnungsunternehmen; Steuerregime: Kapitalgesellschaft; Fachmodus
      
      Kennzahlen
        Endwertdifferenz (Primärkennzahl)                   3.726,41 €
        Endwertdifferenz (ohne Restwert)                  -36.273,59 €
        Endwert                                            38.504,63 €
        Endwert (ohne Restwert)                            -1.495,37 €
        Endwert der Unterlassungsalternative               34.778,22 €
        VoFi-EK-Rendite (modifiziert)                           5,12 %
        VoFi-EK-Rendite (modifiziert) (ohne Restwert)  n. d. (Eigenkapital aufgezehrt)
        Amortisationsdauer                                   5,0 Jahre
        Amortisationsdauer (ohne Restwert)             n. d. (keine Amortisation im Horizont)
        Amortisationsjahr                                         2031
        Minimale Nettoliquidität                           -6.491,30 €
        Maximaler Kontokorrentstand                         6.491,30 €
        Summe der Nachschüsse                                   0,00 €
        Entnahme-Äquivalent                            672,44 EUR/Jahr
      
      VoFi-Tabelle (gekürzt, Summen je Abschnitt)
                                                t0        2027        2028        2029        2030
        Zahlungsfolge der Investition  -100.000,00    6.000,00   10.000,00   30.000,00    8.000,00
        Eigenkapital                     30.000,00        0,00        0,00        0,00        0,00
        Kredite                          70.000,00  -10.995,86  -10.995,86  -10.995,86  -10.995,86
        Kontokorrent                          0,00    4.995,86      995,86   -7.140,43        0,00
        Geldanlage                            0,00        0,00        0,00  -11.863,72    2.995,86
        Steuern                               0,00        0,00        0,00        0,00        0,00
        Finanzierungssaldo                    0,00        0,00        0,00        0,00        0,00
        Bestandssaldo                   -70.000,00  -67.900,00  -61.873,83  -35.545,92  -29.734,58
      
                                             2031
        Zahlungsfolge der Investition   70.000,00
        Eigenkapital                         0,00
        Kredite                        -40.995,86
        Kontokorrent                         0,00
        Geldanlage                     -29.004,14
        Steuern                              0,00
        Finanzierungssaldo                   0,00
        Bestandssaldo                   38.504,63
      
      Hinweise
        - Ertragsteuern sind nicht berücksichtigt (Rechnung vor Ertragsteuern, Steuermodul none).
        - Steuerwarnhinweis: Für Kapitalgesellschaften ohne erweiterte Kürzung (Niveau etwa 30 %) kann die Rechnung vor Ertragsteuern das Ergebnis deutlich verändern. Keine Steuerberatung; Abhilfe: Steuermodul tax_flat, sobald verfügbar.
      
      Prüfungen: Finanzierungssaldo 0 in jeder Periode, alle Invarianten erfüllt.

---

    Code
      print(summary(x))
    Output
      VoFi-Ergebnis: testkit (oracle_a), Variante base
      Deterministischer Lauf, Stichtag 01.01.2027, Horizontende 01.01.2032 (T = 5)
      Perspektive: Privates Wohnungsunternehmen; Steuerregime: Kapitalgesellschaft; Fachmodus
      
      Ampel
        Gesamt: gelb (Wirtschaftlichkeit: gelb; Grundlage: nur Basisfall)
        Keine Robustheitsprüfung (weder Simulation noch Szenario-Set „vorsichtig“); die Ampel ist höchstens gelb.
        Ergebnis hängt am Restwert.
        Restriktion nicht prüfbar: Kapitaldienstdeckung unter Schwelle.
        Restriktion nicht prüfbar: Liquiditätsengpass bzw. Kontokorrent über Limit.
      
      Kennzahlen mit Restwert
        Endwert                                 38.504,63 €
        Endwertdifferenz (Primärkennzahl)        3.726,41 €
        EK-Rentabilität (klassisch)                  5,12 %
        VoFi-EK-Rendite (modifiziert)                5,12 %
        Equity-IRR                                   5,12 %
        Amortisationsdauer                        5,0 Jahre
        Amortisationsjahr                              2031
        Minimale Nettoliquidität                -6.491,30 €
        Maximaler Kontokorrentstand              6.491,30 €
        Maximaler Finanzierungsbedarf            6.491,30 €
        Entnahme-Äquivalent                 672,44 EUR/Jahr
        Kapitalwert der Zahlungsfolge           10.195,96 €
        Interner Zinsfuß der Zahlungsfolge           5,56 %
      
      Kennzahlen ohne Restwert
        Endwert (ohne Restwert)                               -1.495,37 €
        Endwertdifferenz (ohne Restwert)                     -36.273,59 €
        EK-Rentabilität (klassisch) (ohne Restwert)    n. d. (Eigenkapital aufgezehrt)
        VoFi-EK-Rendite (modifiziert) (ohne Restwert)  n. d. (Eigenkapital aufgezehrt)
        Equity-IRR (ohne Restwert)                     n. d. (Eigenkapital aufgezehrt)
        Amortisationsdauer (ohne Restwert)             n. d. (keine Amortisation im Horizont)
        Amortisationsjahr (ohne Restwert)              n. d. (keine Amortisation im Horizont)
        Minimale Nettoliquidität (ohne Restwert)              -6.491,30 €
        Maximaler Kontokorrentstand (ohne Restwert)            6.491,30 €
        Maximaler Finanzierungsbedarf (ohne Restwert)          6.491,30 €
        Entnahme-Äquivalent (ohne Restwert)            -6.669,52 EUR/Jahr
      
      Kennzahlen unabhängig vom Restwert
        Endwert der Unterlassungsalternative  34.778,22 €
        Summe der Nachschüsse                      0,00 €
        Barwert der Nachschüsse                    0,00 €
        Nachschuss bzw. Fehlbetrag                   nein
        Limitüberschreitung                          nein
        Liquiditätsreserve genutzt                   nein
      
      Hinweise
        - Ertragsteuern sind nicht berücksichtigt (Rechnung vor Ertragsteuern, Steuermodul none).
        - Steuerwarnhinweis: Für Kapitalgesellschaften ohne erweiterte Kürzung (Niveau etwa 30 %) kann die Rechnung vor Ertragsteuern das Ergebnis deutlich verändern. Keine Steuerberatung; Abhilfe: Steuermodul tax_flat, sobald verfügbar.
      
      Prüfungen: Finanzierungssaldo 0 in jeder Periode, alle Invarianten erfüllt.

