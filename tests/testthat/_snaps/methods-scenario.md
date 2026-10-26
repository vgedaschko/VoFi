# Snapshots von print() und summary() eines Szenarios (15.6)

    Code
      print(sc)
    Output
      VoFi-Szenario
        Gerüst: Minimalszenario (id skeleton)
        Perspektive Privates Wohnungsunternehmen, Projektart Neubau, Stichtag 01.01.2027, Horizont 3 Jahre
        Quelle: <Datei>
        1 Komponenten, 2 Finanzierungsbausteine, 0 Maßnahmen, 0 Wohnungsgruppen, 0 Förderinstrumente
        Varianten: base

---

    Code
      print(summary(sc))
    Output
      VoFi-Szenario
        Gerüst: Minimalszenario (id skeleton)
        Perspektive Privates Wohnungsunternehmen, Projektart Neubau, Stichtag 01.01.2027, Horizont 3 Jahre
        1 Komponenten, 2 Finanzierungsbausteine, 0 Maßnahmen, 0 Wohnungsgruppen, 0 Förderinstrumente
      
      Blätter je Block
        Block       Blätter
        meta              2
        project           4
        components        4
        financing         9
        accounts          5
        analysis          1
      
      Zahlungskomponenten
        id            Typ    Bezeichnung  Herkunft
        z   custom_series  Zahlungsfolge  scenario
      
      Finanzierungsbausteine
        id            Typ  Bezeichnung  Herkunft
        ek         equity               scenario
        bank  bullet_loan               scenario
      
      Varianten
        Variante  Bezeichnung  erweitert
        base            Basis
      
      Herkunft der Angaben: scenario: 26

