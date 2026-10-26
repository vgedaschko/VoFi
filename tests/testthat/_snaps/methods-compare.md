# Snapshots von print() und summary() (15.6)

    Code
      print(cmp)
    Output
      Variantenvergleich: testkit
      Referenz base; Varianten a; deterministisch
      
      Kennzahlen je Variante (bei Simulation Mittelwerte)
        Kennzahl              base         a
        Endwertdifferenz   3.726 €   5.726 €
        Endwert           38.505 €  40.505 €
      
      Vergleich gegenüber der Referenz (Vergleichsregel: Endwertdifferenz der Variante minus Endwertdifferenz der Referenz)
        Variante  Kennzahl                                  Mittel       P5   Median      P95  P(besser)
        a         Endwertdifferenz gegenüber der Referenz  2.000 €  2.000 €  2.000 €  2.000 €    100,0 %
      
      Rangfolge: 1. a, 2. base (Kriterium: Endwertdifferenz gegenüber der Referenz)
      
      Ampel
        a: gelb (nur Basisfall). Ergebnis hängt am Restwert.
      
      Vergleichbarkeit: keine Befunde.

---

    Code
      print(summary(cmp))
    Output
      Variantenvergleich: testkit
      Referenz base; Varianten a; deterministisch
      
      Alle Kennzahlen je Variante (bei Simulation Mittelwerte)
        Kennzahl              base         a
        Endwertdifferenz   3.726 €   5.726 €
        Endwert           38.505 €  40.505 €
      
      Vergleich gegenüber der Referenz (Vergleichsregel: Endwertdifferenz der Variante minus Endwertdifferenz der Referenz)
        Variante  Kennzahl                                  Mittel       P5   Median      P95  P(besser)
        a         Endwertdifferenz gegenüber der Referenz  2.000 €  2.000 €  2.000 €  2.000 €    100,0 %
      
      Ampel
        a: gelb (nur Basisfall). Ergebnis hängt am Restwert.
      
      Vergleichbarkeit: keine Befunde.

