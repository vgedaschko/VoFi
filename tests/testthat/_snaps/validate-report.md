# Snapshot des Validierungsberichts (Spec 00 15.6)

    Code
      print(v)
    Output
      Validierung: 2 Fehler, 1 Warnungen, 0 Hinweise
      [Fehler] Unbekanntes Feld 'accounts.deposit_rate'; der Wert wird nicht verwendet. Meinten Sie 'deposit_rate_pa'? [Varianten: base, v1]
      [Fehler] 'accounts.overdraft_rate_pa': 0.5 liegt außerhalb des zulässigen Bereichs [0, 0.25]. [Varianten: base, v1]
      [Warnung] 'project.comparison_mode' = differential: Vereinfachungsmodus mit Differenzzahlungen. [Varianten: base, v1]

---

    Code
      print(v, max_rows = 2)
    Output
      Validierung: 2 Fehler, 1 Warnungen, 0 Hinweise
      [Fehler] Unbekanntes Feld 'accounts.deposit_rate'; der Wert wird nicht verwendet. Meinten Sie 'deposit_rate_pa'? [Varianten: base, v1]
      [Fehler] 'accounts.overdraft_rate_pa': 0.5 liegt außerhalb des zulässigen Bereichs [0, 0.25]. [Varianten: base, v1]
      ... und 1 weitere Befunde

