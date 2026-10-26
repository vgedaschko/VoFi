# Snapshot einer Sensitivitätsanalyse (15.6)

    Code
      print(wsh_sensitivity("tornado"))
    Output
      Sensitivitätsanalyse (Tornado): Endwertdifferenz, Variante base
      Basiswert: 3.726 €
      
        Parameter      Wert unten  Wert oben  Kennzahl unten  Kennzahl oben  Spannweite  Rang
        Zahlungsfolge      0,9000     1,1000        -1.000 €        8.000 €     9.000 €     1
        Habenzins          0,0200     0,0400         3.000 €        4.500 €     1.500 €     2

---

    Code
      print(wsh_sensitivity("global"))
    Output
      Sensitivitätsanalyse (globale Sensitivität aus der Simulation): Endwertdifferenz, Variante base
      Basiswert: 3.726 €
      
        Eingangsgröße        Spearman     SRC    SRRC    PRCC  Haupteffekt
        components.z.values     0,810   0,700   0,750   0,900        0,600
        market.inflation       -0,200  -0,100  -0,150  -0,300        0,050
      
      Bestimmtheitsmaß der linearen Regression (SRC): R² = 0,830

