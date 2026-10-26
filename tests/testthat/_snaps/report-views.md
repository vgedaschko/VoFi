# Snapshots der Sichten (15.6)

    Code
      print(tv[, c("year", "rent", "levy", "operating", "energy", "warm_rent", "warm_rent_pre",
        "change_prepost")], digits = 6)
    Output
        year rent levy operating energy warm_rent warm_rent_pre change_prepost
      1 2027    6 0.25         2 0.4165    8.6665       9.42978      -0.763285
      2 2028    6 0.25         2 0.4165    8.6665       9.42978      -0.763285
      3 2029    6 0.25         2 0.4165    8.6665       9.42978      -0.763285
      4 2030    6 0.25         2 0.4165    8.6665       9.42978      -0.763285
      5 2031    6 0.25         2 0.4165    8.6665       9.42978      -0.763285
      6 2032    6 0.25         2 0.4165    8.6665       9.42978      -0.763285

---

    Code
      writeLines(attr(hv, "summary")$text)
    Output
      Ihre monatliche Belastung beträgt im ersten vollen Nutzungsjahr rund 530 € (ohne Tilgung rund 390 €).
      In der Bauphase beträgt Ihre monatliche Belastung einschließlich der bisherigen Miete rund 1.100 €.
      Die Belastung beträgt höchstens rund 13 % Ihres Nettoeinkommens.
      Über 8 Jahre zahlen Sie insgesamt rund 60.500 € (Eigenanteil und laufende Belastung, nominal).
      Ihr Eigenanteil nach Förderung (Einmalbetrag) beträgt rund 10.000 €.
      Nachschüsse sind nicht nötig.
      Ob sich die Investition bezahlt macht, lässt sich bei einem Bestandsgebäude nur im Vergleich mit einer Referenzvariante bestimmen (der Vermögensvergleich mit der Unterlassung enthält die ohnehin anfallenden Kosten des Bestands).

