# Snapshots von print() und summary() (15.6)

    Code
      print(mc)
    Output
      Monte-Carlo-Simulation: testkit (oracle_a), Variante base
      200 Läufe, Seed 20261025, Verfahren lhs, 1 Replikat(e) zu 200 Läufen
      
      Statistik der wichtigsten Kennzahlen (Basisfall daneben)
        Kennzahl                              Basisfall     Mittel      SE         P5        P25
        Endwertdifferenz (Primärkennzahl)       3.726 €    3.726 €   424 €   -6.015 €     -297 €
        Endwertdifferenz (ohne Restwert)      -36.274 €  -36.274 €   424 €  -46.015 €  -40.297 €
        Endwert                                38.505 €   38.505 €   424 €   28.764 €   34.481 €
        Endwert (ohne Restwert)                -1.495 €   -1.495 €   424 €  -11.236 €   -5.519 €
        Endwert der Unterlassungsalternative   34.778 €   34.778 €     0 €   34.778 €   34.778 €
        VoFi-EK-Rendite (modifiziert)            5,12 %     5,12 %  0,08 %     3,17 %     4,31 %
        Nachschuss bzw. Fehlbetrag                    0      6,5 %   1,7 %          0          0
      
        Kennzahl                                 Median        P75        P95   P(< 0)  NA-Anteil
        Endwertdifferenz (Primärkennzahl)       3.726 €    7.750 €   13.467 €   26,5 %      0,0 %
        Endwertdifferenz (ohne Restwert)      -36.274 €  -32.250 €  -26.533 €  100,0 %      0,0 %
        Endwert                                38.505 €   42.528 €   48.246 €    0,0 %      0,0 %
        Endwert (ohne Restwert)                -1.495 €    2.528 €    8.246 €   60,0 %      0,0 %
        Endwert der Unterlassungsalternative   34.778 €   34.778 €   34.778 €    0,0 %      0,0 %
        VoFi-EK-Rendite (modifiziert)            5,12 %     5,92 %     7,07 %    0,0 %      0,0 %
        Nachschuss bzw. Fehlbetrag                    0          0          1    0,0 %      0,0 %
      
        - Standardfehler aus sd/√n bei nur einem Replikat (überschätzt bei LHS).
        - Konvergenz erreicht bei 0 von 7 Kennzahlen.

---

    Code
      print(summary(mc))
    Output
      Monte-Carlo-Simulation: testkit (oracle_a), Variante base
      200 Läufe, Seed 20261025, Verfahren lhs, 1 Replikat(e) zu 200 Läufen
      
      Risiko in Worten
        - In 7 von 10 simulierten Zukünften ist die Endwertdifferenz positiv.
        - Wahrscheinlichkeit eines negativen Werts: 26,50 % ± 3,12 Prozentpunkte (MC-Fehler).
        - In 8 von 10 simulierten Zukünften liegt der Wert zwischen -3.895 € und 11.348 €.
        - 5-%-Quantil: -6.015 €.
        - Mittel der schlechtesten 5 %: -8.592 €.
        - Erwarteter Verlust: 975 €.
      
      Statistik aller Kennzahlen
        Kennzahl                              Basisfall     Mittel      SE         P5        P25
        Endwert                                38.505 €   38.505 €   424 €   28.764 €   34.481 €
        Endwert (ohne Restwert)                -1.495 €   -1.495 €   424 €  -11.236 €   -5.519 €
        Endwert der Unterlassungsalternative   34.778 €   34.778 €     0 €   34.778 €   34.778 €
        Endwertdifferenz (Primärkennzahl)       3.726 €    3.726 €   424 €   -6.015 €     -297 €
        Endwertdifferenz (ohne Restwert)      -36.274 €  -36.274 €   424 €  -46.015 €  -40.297 €
        VoFi-EK-Rendite (modifiziert)            5,12 %     5,12 %  0,08 %     3,17 %     4,31 %
        Nachschuss bzw. Fehlbetrag                    0      6,5 %   1,7 %          0          0
      
        Kennzahl                                 Median        P75        P95   P(< 0)  NA-Anteil
        Endwert                                38.505 €   42.528 €   48.246 €    0,0 %      0,0 %
        Endwert (ohne Restwert)                -1.495 €    2.528 €    8.246 €   60,0 %      0,0 %
        Endwert der Unterlassungsalternative   34.778 €   34.778 €   34.778 €    0,0 %      0,0 %
        Endwertdifferenz (Primärkennzahl)       3.726 €    7.750 €   13.467 €   26,5 %      0,0 %
        Endwertdifferenz (ohne Restwert)      -36.274 €  -32.250 €  -26.533 €  100,0 %      0,0 %
        VoFi-EK-Rendite (modifiziert)            5,12 %     5,92 %     7,07 %    0,0 %      0,0 %
        Nachschuss bzw. Fehlbetrag                    0          0          1    0,0 %      0,0 %
      
        - Standardfehler aus sd/√n bei nur einem Replikat (überschätzt bei LHS).
        - Konvergenz erreicht bei 0 von 7 Kennzahlen.
      
      Prüfungen: alle Invarianten in allen Läufen erfüllt.

