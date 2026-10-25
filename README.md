# vofi

R-Paket für den **Vollständigen Finanzplan (VoFi)** nach Grob mit
Monte-Carlo-Simulation zur Wirtschaftlichkeitsbewertung von Neubau und
energetischer Sanierung von Wohngebäuden in Deutschland – aus Sicht von
Wohnungsunternehmen, privaten Vermietern und Selbstnutzern.

**Status:** in Entwicklung (Phase 0: Paketgerüst und Kernverträge). Die
meisten exportierten Funktionen sind noch Platzhalter und melden
`vofi_error_not_implemented`.

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
