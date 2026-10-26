# Snapshots der VoFi-Tabelle (13.6, 15.6)

    Code
      print(vofi_table(x))
    Output
      VoFi-Tabelle (Grob-Layout, Summen je Kategorie): testkit, Variante base, Lauf 1
        Position                                                            t0        2027        2028
        Zahlungsfolge der Investition                              -100.000,00    6.000,00   10.000,00
          Zahlung (frei)                                           -100.000,00    6.000,00   10.000,00
          Restwert                                                           –           –           –
        Einlage                                                      30.000,00           –           –
        Entnahme                                                             –           –           –
        ann: Aufnahme                                                40.000,00           –           –
        ann: Tilgung                                                         –   -7.095,86   -7.521,61
        ann: Schlusstilgung                                                  –           –           –
        ann: Sondertilgung                                                   –           –           –
        ann: Sollzinsen                                                      –   -2.400,00   -1.974,25
        ann: Gebühren und Provisionen                                        –           –           –
        bul: Aufnahme                                                30.000,00           –           –
        bul: Tilgung                                                         –           –           –
        bul: Schlusstilgung                                                  –           –           –
        bul: Sondertilgung                                                   –           –           –
        bul: Sollzinsen                                                      –   -1.500,00   -1.500,00
        bul: Gebühren und Provisionen                                        –           –           –
        Kontokorrent: Aufnahme                                               –    4.995,86    1.495,44
        Kontokorrent: Tilgung                                                –           –           –
        Kontokorrent: Sollzinsen                                             –           –     -499,59
        Geldanlage: Anlage                                                   –           –           –
        Geldanlage: Auflösung                                                –           –           –
        Geldanlage: Habenzinsen                                              –           –           –
        Ertragsteuern (nicht berücksichtigt)                                 –           –           –
        Finanzierungssaldo                                                0,00        0,00        0,00
        Bestand ann                                                  40.000,00   32.904,14   25.382,54
        Bestand bul                                                  30.000,00   30.000,00   30.000,00
        Bestand Kontokorrent                                                 –    4.995,86    6.491,30
        Bestand Geldanlage                                                   –           –           –
        Offene Steuer am Horizont                                            –           –           –
        Bestandssaldo                                               -70.000,00  -67.900,00  -61.873,83
        Bestandssaldo ohne Restwert (in T: Endwert ohne Restwert)   -70.000,00  -67.900,00  -61.873,83
      
        Position                                                         2029        2030        2031
        Zahlungsfolge der Investition                               30.000,00    8.000,00   70.000,00
          Zahlung (frei)                                            30.000,00    8.000,00   30.000,00
          Restwert                                                          –           –   40.000,00
        Einlage                                                             –           –           –
        Entnahme                                                            –           –           –
        ann: Aufnahme                                                       –           –           –
        ann: Tilgung                                                -7.972,90   -8.451,28   -8.958,35
        ann: Schlusstilgung                                                 –           –           –
        ann: Sondertilgung                                                  –           –           –
        ann: Sollzinsen                                             -1.522,95   -1.044,58     -537,50
        ann: Gebühren und Provisionen                                       –           –           –
        bul: Aufnahme                                                       –           –           –
        bul: Tilgung                                                        –           –           –
        bul: Schlusstilgung                                                 –           –  -30.000,00
        bul: Sondertilgung                                                  –           –           –
        bul: Sollzinsen                                             -1.500,00   -1.500,00   -1.500,00
        bul: Gebühren und Provisionen                                       –           –           –
        Kontokorrent: Aufnahme                                              –           –           –
        Kontokorrent: Tilgung                                       -6.491,30           –           –
        Kontokorrent: Sollzinsen                                      -649,13           –           –
        Geldanlage: Anlage                                         -11.863,72           –  -29.280,86
        Geldanlage: Auflösung                                               –    2.639,94           –
        Geldanlage: Habenzinsen                                             –      355,91      276,71
        Ertragsteuern (nicht berücksichtigt)                                –           –           –
        Finanzierungssaldo                                               0,00        0,00        0,00
        Bestand ann                                                 17.409,63    8.958,35           –
        Bestand bul                                                 30.000,00   30.000,00           –
        Bestand Kontokorrent                                                –           –           –
        Bestand Geldanlage                                          11.863,72    9.223,77   38.504,63
        Offene Steuer am Horizont                                           –           –           –
        Bestandssaldo                                              -35.545,92  -29.734,58   38.504,63
        Bestandssaldo ohne Restwert (in T: Endwert ohne Restwert)  -35.545,92  -29.734,58   -1.495,37

---

    Code
      print(vofi_table(x, detail = "full", periods = 0:2))
    Output
      VoFi-Tabelle (Grob-Layout, alle Zeilen): testkit, Variante base, Lauf 1
        Position                                                            t0        2027        2028
        Zahlungsfolge der Investition                              -100.000,00    6.000,00   10.000,00
          Zahlungsfolge: Zahlung                                   -100.000,00    6.000,00   10.000,00
          Restwert: Zahlung                                                  –           –           –
        Einlage                                                      30.000,00           –           –
        Entnahme                                                             –           –           –
        Nachschuss                                                           –           –           –
        Nicht gedeckter Fehlbetrag                                           –           –           –
        ann: Aufnahme                                                40.000,00           –           –
        ann: Tilgung                                                         –   -7.095,86   -7.521,61
        ann: Schlusstilgung                                                  –           –           –
        ann: Sondertilgung                                                   –           –           –
        ann: Sollzinsen                                                      –   -2.400,00   -1.974,25
        ann: Gebühren und Provisionen                                        –           –           –
        ann: Tilgungszuschuss (zahlungsunwirksam)                            –           –           –
        ann: Disagio (zahlungsunwirksam)                                     –           –           –
        ann: Übernommene Restschuld (zahlungsunwirksam)                      –           –           –
        bul: Aufnahme                                                30.000,00           –           –
        bul: Tilgung                                                         –           –           –
        bul: Schlusstilgung                                                  –           –           –
        bul: Sondertilgung                                                   –           –           –
        bul: Sollzinsen                                                      –   -1.500,00   -1.500,00
        bul: Gebühren und Provisionen                                        –           –           –
        bul: Tilgungszuschuss (zahlungsunwirksam)                            –           –           –
        bul: Disagio (zahlungsunwirksam)                                     –           –           –
        bul: Übernommene Restschuld (zahlungsunwirksam)                      –           –           –
        Kontokorrent: Aufnahme                                               –    4.995,86    1.495,44
        Kontokorrent (Strafzins): Aufnahme                                   –           –           –
        Kontokorrent: Tilgung                                                –           –           –
        Kontokorrent (Strafzins): Tilgung                                    –           –           –
        Kontokorrent: Sollzinsen                                             –           –     -499,59
        Kontokorrent (Strafzins): Sollzinsen                                 –           –           –
        Geldanlage: Anlage                                                   –           –           –
        Geldanlage: Auflösung                                                –           –           –
        Geldanlage: Habenzinsen                                              –           –           –
        Ertragsteuern (nicht berücksichtigt)                                 –           –           –
        Abgeltungsteuer auf Habenzinsen                                      –           –           –
        Finanzierungssaldo                                                0,00        0,00        0,00
        Bestand ann                                                  40.000,00   32.904,14   25.382,54
        Bestand bul                                                  30.000,00   30.000,00   30.000,00
        Bestand Kontokorrent                                                 –    4.995,86    6.491,30
        Bestand Kontokorrent (Strafzins)                                     –           –           –
        Bestand Geldanlage                                                   –           –           –
        Offene Steuer am Horizont                                            –           –           –
        Bestandssaldo                                               -70.000,00  -67.900,00  -61.873,83
        Bestandssaldo ohne Restwert (in T: Endwert ohne Restwert)   -70.000,00  -67.900,00  -61.873,83

---

    Code
      print(vofi_table(x, layout = "transposed", periods = c(0, 5)))
    Output
      VoFi-Tabelle (transponiert, Summen je Kategorie): testkit, Variante base, Lauf 1
        Periode  Zahlungsfolge der Investition  Zahlung (frei)   Restwert    Einlage  Entnahme
        t0                         -100.000,00     -100.000,00          –  30.000,00         –
        2031                         70.000,00       30.000,00  40.000,00          –         –
      
        Periode  ann: Aufnahme  ann: Tilgung  ann: Schlusstilgung  ann: Sondertilgung  ann: Sollzinsen
        t0           40.000,00             –                    –                   –                –
        2031                 –     -8.958,35                    –                   –          -537,50
      
        Periode  ann: Gebühren und Provisionen  bul: Aufnahme  bul: Tilgung  bul: Schlusstilgung
        t0                                   –      30.000,00             –                    –
        2031                                 –              –             –           -30.000,00
      
        Periode  bul: Sondertilgung  bul: Sollzinsen  bul: Gebühren und Provisionen
        t0                        –                –                              –
        2031                      –        -1.500,00                              –
      
        Periode  Kontokorrent: Aufnahme  Kontokorrent: Tilgung  Kontokorrent: Sollzinsen
        t0                            –                      –                         –
        2031                          –                      –                         –
      
        Periode  Geldanlage: Anlage  Geldanlage: Auflösung  Geldanlage: Habenzinsen
        t0                        –                      –                        –
        2031             -29.280,86                      –                   276,71
      
        Periode  Ertragsteuern (nicht berücksichtigt)  Finanzierungssaldo  Bestand ann  Bestand bul
        t0                                          –                0,00    40.000,00    30.000,00
        2031                                        –                0,00            –            –
      
        Periode  Bestand Kontokorrent  Bestand Geldanlage  Offene Steuer am Horizont  Bestandssaldo
        t0                          –                   –                          –     -70.000,00
        2031                        –           38.504,63                          –      38.504,63
      
        Periode  Bestandssaldo ohne Restwert (in T: Endwert ohne Restwert)
        t0                                                      -70.000,00
        2031                                                     -1.495,37

