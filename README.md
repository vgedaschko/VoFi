# vofi

R-Paket für den **Vollständigen Finanzplan (VoFi)** nach Grob mit
Monte-Carlo-Simulation zur Wirtschaftlichkeitsbewertung von Neubau und
energetischer Sanierung von Wohngebäuden in Deutschland – aus Sicht von
Wohnungsunternehmen, privaten Vermietern und Selbstnutzern.

**Status:** in Entwicklung (Phase 0: Paketgerüst, Kernverträge und Walking
Skeleton). Der deterministische Lauf ist durchgehend nutzbar; Simulation,
Vergleich, Sensitivität und Berichte sind noch Platzhalter und melden
`vofi_error_not_implemented`.

```r
library(vofi)
res <- vofi_run(vofi_build(vofi_read_scenario(vofi_example("skeleton"))))
print(res)   # Endwert 52.830,80 EUR, Endwertdifferenz 10.382,48 EUR
```

## Installation

Aus dem Quellverzeichnis (Repository-Wurzel = Paketwurzel):

```r
# install.packages("devtools")
devtools::install()
```

## Dokumentation

- Konzept: `docs/Konzept.md`
- verbindliche Spezifikation: `docs/spec/00_kernvertraege.md` (Kernverträge),
  `docs/spec/01*.md` (Feldkatalog)
- Prüfung des Pakets: `tools/check.sh`
