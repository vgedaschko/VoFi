# Recherche-Memo 04: Monte-Carlo-Simulation im VoFi-Tool

**Methodik und Umsetzungsstrategie in R**

Stand: 25.10.2026 · Kontext: VoFi nach Grob für Neubau und energetische Sanierung von Wohngebäuden (Wohnungsunternehmen, Selbstnutzer, private Kleinvermieter), v1 vor Steuern · Prototyp-Rechnungen mit R 4.3.3 (Linux-Container, 4 Kerne, 15 GB RAM)

---

## 0. Kurzfassung und Kernentscheidungen

Die Monte-Carlo-Simulation (MC) soll keinen eigenen Rechenkern bekommen. Der VoFi-Rechenkern wird von Anfang an **über die Simulationen vektorisiert**: Jede Größe ist ein Vektor der Länge N, Zeitreihen sind N×T-Matrizen, und die Schleife läuft nur über die Perioden t = 0…T. Die deterministische Rechnung ist dann einfach der Fall N = 1. Ein Prototyp mit 29 VoFi-Zeilen, zwei Darlehen (eines mit stochastischer Anschlussfinanzierung), Kontokorrent und Geldanlage braucht für N = 10.000 und T = 40 **etwa 0,1 s**. Die naive Alternative, eine skalare Engine 10.000-mal aufzurufen, braucht 36–47 s.

| Nr. | Entscheidung / Empfehlung | Abschnitt |
|---|---|---|
| E1 | **Eine Engine, vektorisiert über Simulationen** (Vektoren der Länge N, N×T-Matrizen). Die deterministische Rechnung ist N = 1, ohne eigenen Code. | 5 |
| E2 | Stochastik als **Overlay-Spezifikation in YAML** (Schlüssel englisch, `label` deutsch). Jeder Eintrag verweist per `target` auf eine deterministische Eingabe. Der Basisfall bleibt unverändert und wird separat gerechnet. | 10 |
| E3 | **Zwei Klassen**: statische Parameter mit einer Ziehung je Simulation (Inversionsmethode; `fixed`, `normal`, `truncnorm`, `lognormal`, `uniform`, `triangular`, `pert`, `bernoulli`, `discrete`, `empirical`) und Prozesse mit einem Pfad je Simulation (`ar1`, `linked_ar1`, `vasicek`, `mr_trend`, `gbm`, `scenario_mix`, `iid`, `bootstrap`, `fixed_path`). **Prozessparameter dürfen selbst verteilt sein** (Trendunsicherheit). | 2 |
| E4 | **Strukturelle Kopplungen haben Vorrang vor Korrelationen**: Miete ~ Inflation, Baupreis ~ Inflation, Haben-/Kontokorrentzins ~ Bauzins, Exit-Rendite ~ Zins in T, Energiepreis = Commodity-Anteil + CO₂-Preis × Emissionsfaktor, Vermieteranteil der CO₂-Kosten nach Stufenmodell. | 1, 3 |
| E5 | Abhängigkeiten zwischen statischen Parametern über **Rangkorrelation (Spearman) mit Iman–Conover**; die Gauß-Copula ist Option. Prozessschocks werden je Periode über eine Cholesky-Zerlegung korreliert. Nicht positiv definite Matrizen werden repariert (Eigenwert-Clipping, alternativ `Matrix::nearPD`), mit Warnung. | 3 |
| E6 | Standardverfahren: **replizierte Latin-Hypercube-Stichprobe (LHS, 10 Replikate)**. Iman–Conover läuft je Replikat getrennt, nur so bleiben die Standardfehler ehrlich. Antithetische Variablen sind Option und nur bei Pseudo-Zufallszahlen sinnvoll. | 4 |
| E7 | **Benannte Zufallsströme**: Der Seed jeder Eingangsgröße wird aus Master-Seed und Namens-Hash gebildet. Ergebnisse sind damit reproduzierbar und bleiben stabil, wenn Parameter hinzukommen oder umsortiert werden. Gemeinsame Zufallszahlen über Varianten ergeben sich automatisch. | 4, 8 |
| E8 | **Common Random Numbers (CRN) sind Pflicht**: Alle Varianten, die Differenz-VoFi und die Opportunität werden auf demselben Szenarioobjekt gerechnet, Differenzen bildet das Tool je Simulation. | 8 |
| E9 | Anzahl der Läufe: **1.000 (Vorschau), 10.000 (Standard), 50.000 (Tail-Kennzahlen, Bericht)**. Den MC-Fehler weist das Tool immer aus (Standardfehler aus den Replikaten, Quantil-Konfidenzintervalle über Ordnungsstatistiken). | 4 |
| E10 | Speicher: **Kennzahlen für alle Läufe; Fächerbänder (Quantile je Periode) werden während der Schleife berechnet**. Volle VoFi-Tabellen gibt es nur für den Basisfall und ausgewählte Läufe (z. B. P5/P50/P95), die das Tool dafür erneut rechnet. | 5 |
| E11 | Sensitivität: Tornado und Spider-Plot in **einem** vektorisierten Lauf, kritische Werte mit `uniroot`. Global aus der MC-Stichprobe: Spearman, SRC/SRRC mit R², PRCC und Haupteffekt-Index über Klassenbildung (binned S1). Sobol-Indizes erst in v2. | 7 |
| E12 | **Keine Parallelisierung in v1**; der Rechenkern ist schnell genug. Optional später `future.apply` über Varianten oder Chunks. Das Sampling bleibt zentral, damit das Ergebnis nicht von der Anzahl der Worker abhängt. | 5 |
| E13 | Zinsen: Vasicek-Prozess mit exakter Diskretisierung und **Floor auf der Ausgabe**. Defaults aus Bundesbank SUD119 kalibriert (κ ≈ 0,12, σ ≈ 0,7 Pp.); das Langfristniveau θ setzen Experten (≈ 3,75 %), weil das Stichprobenmittel 2003–2025 von der Niedrigzinsphase verzerrt ist. | 2.3 |

---

## 1. Stochastische Eingangsgrößen

### 1.1 Grundsätze

1. **Nur Unsicherheit modellieren, die entscheidungsrelevant ist.** Typisch tragen 5 bis 10 Größen über 90 % der Varianz (vgl. Sensitivitätsergebnis in Abschnitt 7.5). Das Tool sollte trotzdem jede numerische Eingabe stochastisch machen können.
2. **Basisfall und Erwartungswert trennen.** Der deterministische Basisfall nutzt die deterministischen Eingaben. Die MC zeigt die Verteilung. Wegen Nichtlinearitäten (Jensen-Ungleichung: E[f(X)] ≠ f(E[X])) und schiefer Verteilungen weicht der MC-Median in der Regel vom Basisfall ab; das Tool weist beide aus.
3. **Struktur vor Statistik.** Wo ein ökonomischer oder rechtlicher Zusammenhang bekannt ist, wird er im Modell abgebildet und nicht über Korrelationen nachgebildet. Beispiele: Indexmiete (§ 557b BGB) folgt der Inflation, Kappungsgrenzen begrenzen Mietsteigerungen, Modernisierungsumlage mit Kappung, CO₂-Kosten-Stufenmodell. Die Rechtslogik bleibt deterministisch (z. B. als `pmin`/`pmax`) und wird auf stochastische Eingaben angewendet.
4. **Perspektiven unterscheiden.** Beim Selbstnutzer wirken Energiepreis- und Einsparungsrisiken direkt. Beim Vermieter wirken sie vor allem über den Vermieteranteil der CO₂-Kosten, die Modernisierungsumlage, Leerstand und Vermietbarkeit. Bei Wohnungsunternehmen kommen Refinanzierungsrisiken und Covenants (DSCR, Beleihungsauslauf) hinzu.
5. **Zeitachse in Kalenderjahren.** Prozesspfade werden über `years` (Startjahr + t) indiziert. Varianten mit anderem Projektbeginn nutzen damit dieselben Kalenderjahr-Pfade (wichtig für CRN).

### 1.2 Katalog der Unsicherheiten

Legende Klasse: **S** = statischer Parameter (eine Ziehung je Simulation), **P** = Prozess (ein Pfad je Simulation), **S→P** = statische Ziehung, die einen Prozess parametrisiert (z. B. Trend).

| Eingangsgröße | Klasse | Empfohlenes Modell | Indikativer Default (zu validieren) | Strukturelle Kopplung / Hinweise |
|---|---|---|---|---|
| **Energiepreise** (Gas, Strom/WP-Tarif, Fernwärme, Öl, Pellets), ohne CO₂-Anteil | P (+S→P) | `mr_trend`: Log-Preis = Trend + AR(1)-Abweichung; Trendwachstum als verteilter Parameter | Gas φ 0,75–0,8, σ 8 %; Strom φ 0,75, σ 4 %; Heizöl φ 0,7, σ 18 %; Trend nominal N(2 %; 1 Pp.) | Gesamtpreis = Commodity-Pfad + CO₂-Preis × Emissionsfaktor (Gas ≈ 0,2 t CO₂/MWh) × (1 + USt). Schockkorrelation Gas–Strom ≈ 0,5, Gas–VPI ≈ 0,6–0,8 (Abschnitt 2.3) |
| **CO₂-Preis** (BEHG, ab 2028 EU-ETS 2) | P | `scenario_mix` (3–4 Pfade mit Wahrscheinlichkeiten) + multiplikatives AR(1)-Rauschen | 2026: Korridor 55–65 €/t; 2027: Korridor 55–65 €/t (Gesetzentwurf); ab 2028 ETS 2; Szenarien z. B. niedrig 70/90/100, mittel 120/200/250, hoch 200/300/350 €/t (2030/2045/2066) | Vermieteranteil nach CO2KostAufG (10 Stufen nach kg CO₂/m²a) hängt vom tatsächlichen Verbrauch ab und ist damit stochastisch (vektorisiert über `findInterval`) |
| **Bauzins für die Anschlussfinanzierung** nach Ende der Zinsbindung | P | `vasicek` (exakt), Floor auf der Ausgabe | r₀ = aktueller Wert (≈ 4,0 %, SUD119 08/2026), θ 3,75 %, κ 0,12, σ 0,7 Pp., Floor 0,5 % | Neuer Zins = Pfadwert im Jahr vor dem Reset + Spread; Habenzins = max(r − 1,5 Pp.; 0); Kontokorrent = r + Spread. Optional Kündigungsrecht nach § 489 BGB als vektorisierte Option |
| **Inflation (VPI)** | P (+S→P) | `ar1` auf der Jahresrate; μ als verteilter Parameter | μ ~ N(2,0 %; 0,3–0,5 Pp.), φ 0,5–0,55, σ_ε 1,0–1,4 Pp. | Basis für Verwaltungskosten, Indexmiete, Baupreis- und Instandhaltungsentwicklung |
| **Mietentwicklung** | P | `linked_ar1`: g = a + b·π + AR(1) | Bestandsmiete: a 0, b 0,6–0,8, σ 0,4–0,6 Pp.; Neuvertrags-/Marktmiete: σ 2–3 Pp. | Vertragstyp bestimmt die Logik: Indexmiete g = π; Staffelmiete deterministisch; Vergleichsmiete: Marktpfad mit Kappungsgrenze (`pmin`). Neubau-Erstvermietung ist von der Mietpreisbremse ausgenommen |
| **Baupreis- und Instandhaltungskostenentwicklung** | P | `linked_ar1`: g = a + b·π + AR(1) | a 0,5–0,7 Pp., b 1,0–1,5, φ 0,6–0,7, σ 1,5 Pp. | Ersatzinvestitionen und Instandhaltung werden mit dem Baupreisindex fortgeschrieben |
| **Leerstand / Mietausfall** | S + P | Niveau als S (PERT oder Lognormal, gestutzt), jährliche Schwankung als `iid` | Niveau PERT(0; 2 %; 8 %); Mietausfallwagnis 2 % deterministisch | Regional sehr unterschiedlich. Beim Selbstnutzer entfällt die Größe |
| **Baukostenüberschreitung** | S | PERT (Expertenschätzung) oder verschobene Lognormalverteilung (Median/P90) | Neubau PERT(0,95; 1,05; 1,35); Sanierung im Bestand PERT(0,95; 1,10; 1,50) | Mehrkosten fließen ohne Zusatzlogik über die Ausgleichsregel in Kontokorrent oder Eigenkapitalnachschuss |
| **Bauzeitverzug** | S | PERT in Monaten | Neubau PERT(0; 2; 12); Sanierung PERT(0; 1; 6) | Rangkorrelation mit Kostenüberschreitung ρ_S ≈ 0,5. Wirkt auf Mietbeginn (Belegungsanteil), Bauzeit- und Bereitstellungszinsen sowie Preissteigerung während des Verzugs |
| **Förderrisiko** (Zusage, Programmänderung, Höhe) | S | `bernoulli` (Zusage), `discrete` (Förderquote/Programm) | p(Zusage) 0,8–0,95; Quote z. B. {0 %: 0,1; 15 %: 0,5; 20 %: 0,4} | Tilgungszuschuss reduziert den Darlehensbestand, ein Zuschuss ist eine Einzahlung. Fehlt die Förderung, deckt die Ausgleichsregel die Lücke |
| **Exit-Rendite / Restwert** | S (+ Kopplung an P) | y_exit = y₀ + β·(r_T − r₀) + ε, ε ~ N(0; σ) | y₀ aus dem Liegenschaftszins (3,0–4,5 %), β 0,5, σ 0,4 Pp.; Untergrenze 2 % | Restwert = NOI_{T+1}/y_exit. Selbstnutzer: Verkehrswert mit Effizienzaufschlag PERT(0; 3 %; 8 %), zu prüfen |
| **Nutzungsdauern von Bauteilen** | S | PERT oder Dreieck je Bauteil, BNB-Nutzungsdauer als Modus | WP PERT(12; 18; 25), Fenster (25; 35; 45), WDVS (30; 40; 50) | Ganzzahlige Rundung erzeugt Sprungstellen. Anteiliger Restwert des letzten Ersatzes glättet sie (Abschnitt 7.3) |
| **Einsparrealisierung** (Performance Gap, Prebound, Rebound) | S | Strukturell: f_pre (Ist/Bedarf vor Sanierung) und f_post (Ist/Bedarf danach) als PERT. Alternativ ein Realisierungsfaktor | f_pre PERT(0,5; 0,7; 1,0) bei hohem Bedarfswert; f_post PERT(0,9; 1,1; 1,4); ρ_S(f_pre, f_post) ≈ 0,3. Alternativ Realisierung PERT(0,4; 0,8; 1,05) | **Wenn Verbrauchsdaten vorliegen, ist die Basis der gemessene Verbrauch** und f_pre entfällt. Literatur: im Mittel rund 30 % Prebound in Deutschland (Sunikka-Blank/Galvin 2012); Schweiz: realisierte Einsparung 37 % unter Rechenwert (Cozza et al. 2019) |
| **Jahresarbeitszahl Wärmepumpe** | S | PERT | Bestand PERT(2,6; 3,2; 4,0); Neubau PERT(3,2; 3,8; 4,6) | Stromkosten = Wärmebedarf / JAZ × Strompreis |
| **Instandhaltungs- und Bewirtschaftungsniveau** | S | PERT als Faktor | PERT(0,85; 1,0; 1,3) | Mit dem Baupreispfad fortgeschrieben |
| **Witterung** (optional) | P | `iid` Normal als Gradtagzahl-Faktor | N(1; 0,08) | Erhöht nur die Liquiditätsschwankung; geringe Wirkung auf den Endwert |

**Zur Prebound/Rebound-Struktur.** Berechneter Bedarf vor und nach Sanierung sei $Q^{calc}_{pre}$ und $Q^{calc}_{post}$. Der tatsächliche Verbrauch ist $Q_{pre} = f_{pre}\,Q^{calc}_{pre}$ und $Q_{post} = f_{post}\,Q^{calc}_{post}$, die Einsparung $\Delta Q = Q_{pre} - Q_{post}$. Der implizite Realisierungsgrad ist $\Delta Q / (Q^{calc}_{pre} - Q^{calc}_{post})$. Diese Zerlegung zeigt, warum die Einsparung bei hohem Bedarfswert besonders stark überschätzt wird. Die Kurzform mit nur einem Realisierungsfaktor eignet sich, wenn keine Bedarfsausweise vorliegen.

---

## 2. Zwei Klassen von Zufallsgrößen

Alle Ziehungen folgen der **Inversionsmethode**. Zuerst entstehen gleichverteilte Basiszahlen $u \in (0,1)$, pseudo-zufällig oder per LHS (Abschnitt 4). Dann gilt $x = F^{-1}(u)$. Die Methode ist nötig, weil sie mit LHS, Gauß-Copula und antithetischen Variablen zusammenpasst und weil die Monotonie zwischen u und x die Rangkorrelation erhält.

### 2.1 Statische Parameter (eine Ziehung je Simulation)

| `dist` | Parameter (YAML) | Quantilfunktion $x = F^{-1}(u)$ | Momente / Hinweise |
|---|---|---|---|
| `fixed` | `value` | $x = c$ | Degenerierter Fall; die Engine-Ergebnisse müssen dann dem Basisfall entsprechen |
| `normal` | `mean`, `sd` | $x = \mu + \sigma\,\Phi^{-1}(u)$ | Nur für unbeschränkte Größen (z. B. Exit-Schock) |
| `truncnorm` | `mean`, `sd`, `lower`, `upper` | $x = \mu + \sigma\,\Phi^{-1}\!\big(\Phi(\alpha) + u\,[\Phi(\beta)-\Phi(\alpha)]\big)$ mit $\alpha = (a-\mu)/\sigma$, $\beta = (b-\mu)/\sigma$ | Achtung: `mean`/`sd` beschreiben die Mutterverteilung. $E[X] = \mu + \sigma\,\frac{\varphi(\alpha)-\varphi(\beta)}{\Phi(\beta)-\Phi(\alpha)}$; die Oberfläche zeigt den resultierenden Mittelwert an |
| `lognormal` | `mean`+`sd` **oder** `median`+`p90`, optional `shift` | $x = s + \exp(m + \sigma_l\,\Phi^{-1}(u))$ | Aus Mittelwert/sd: $\sigma_l^2 = \ln(1 + sd^2/mean^2)$, $m = \ln(mean) - \sigma_l^2/2$. Aus Median/P90: $m = \ln(median)$, $\sigma_l = (\ln p_{90} - \ln median)/1{,}2816$. Unbeschränkt; für Quoten nur gestutzt oder als PERT |
| `uniform` | `min`, `max` | $x = a + (b-a)\,u$ | $E = (a+b)/2$, $Var = (b-a)^2/12$; wenn nur die Spanne bekannt ist |
| `triangular` | `min`, `mode`, `max` | Mit $F_c = (c-a)/(b-a)$: für $u < F_c$ gilt $x = a + \sqrt{u(b-a)(c-a)}$, sonst $x = b - \sqrt{(1-u)(b-a)(b-c)}$ | $E = (a+b+c)/3$, $Var = (a^2+b^2+c^2-ab-ac-bc)/18$; die Ränder sind stärker gewichtet als bei PERT |
| `pert` | `min`, `mode`, `max`, optional `lambda` (Default 4) | $x = a + (b-a)\,F^{-1}_{Beta(\alpha,\beta)}(u)$, $\alpha = 1 + \lambda\frac{c-a}{b-a}$, $\beta = 1 + \lambda\frac{b-c}{b-a}$ | $E = (a + \lambda c + b)/(\lambda+2)$, $Var = (E-a)(b-E)/(\lambda+3)$. **Standard für Expertenschätzungen** |
| `bernoulli` | `p` | $x = \mathbb{1}\{u < p\}$ | Mit LHS treten exakt ⌊pN⌋ oder ⌈pN⌉ Erfolge auf |
| `discrete` | `values`, `probs` | $x = v_k$ mit $k = \min\{k: P_k \ge u\}$, $P_k = \sum_{j\le k} p_j$ | Programmvarianten, Förderquoten |
| `empirical` | `data` | Lineare Interpolation der Ordnungsstatistiken (`quantile(type = 7)`) | Aus Stichproben, z. B. Kostenüberschreitungen eigener Projekte |

**Hinweise zur Parametrisierung**

- **PERT aus P10/P90.** Experten nennen eher P10/P90 als absolute Grenzen. Das Tool sollte eine Hilfsfunktion `pert_from_quantiles(p10, mode, p90)` anbieten, die min und max numerisch so bestimmt, dass die Quantile passen (z. B. mit `optim`).
- **Quoten und Anteile** (Leerstand, Realisierungsgrad) nicht als Normal- oder ungestutzte Lognormalverteilung modellieren. Ein Test mit Lognormal(Median 2 %, P90 5 %) ergab für N = 10.000 einen Maximalwert von 35 % Leerstand.
- **Performance:** `qbeta` (PERT) ist langsam: 0,48 s für 400.000 Werte. Für große N×T-Ziehungen tabelliert man die Quantilfunktion auf 4.098 Stützstellen, die in den Rändern verdichtet sind (`pnorm(seq(-7, 7, ...))`), und interpoliert linear. Das kostet 0,035 s bei einem maximalen Fehler von 5·10⁻⁸.

```r
`%||%` <- function(a, b) if (is.null(a)) b else a

q_triangular <- function(u, min, mode, max) {
  fc <- (mode - min) / (max - min)
  ifelse(u < fc, min + sqrt(u * (max - min) * (mode - min)),
                 max - sqrt((1 - u) * (max - min) * (max - mode)))
}
q_pert <- function(u, min, mode, max, lambda = 4) {
  a <- 1 + lambda * (mode - min) / (max - min)
  b <- 1 + lambda * (max - mode) / (max - min)
  min + (max - min) * qbeta(u, a, b)
}
q_truncnorm <- function(u, mean, sd, lower = -Inf, upper = Inf) {
  pa <- pnorm(lower, mean, sd); pb <- pnorm(upper, mean, sd)
  qnorm(pa + u * (pb - pa), mean, sd)
}
lnorm_par <- function(mean = NULL, sd = NULL, median = NULL, p90 = NULL) {
  if (!is.null(mean)) {
    s2 <- log(1 + (sd / mean)^2)
    return(c(meanlog = log(mean) - s2 / 2, sdlog = sqrt(s2)))
  }
  c(meanlog = log(median), sdlog = (log(p90) - log(median)) / qnorm(0.9))
}
q_discrete <- function(u, values, probs) {
  cp <- cumsum(probs) / sum(probs)
  values[findInterval(u, cp, left.open = TRUE) + 1L]
}
q_empirical <- function(u, data) unname(quantile(data, probs = u, type = 7))

# Spezifikation (aus YAML) -> Quantilfunktion
quantile_fun <- function(spec) {
  switch(spec$dist,
    fixed      = function(u) rep(spec$value, length(u)),
    normal     = function(u) qnorm(u, spec$mean, spec$sd),
    truncnorm  = function(u) q_truncnorm(u, spec$mean, spec$sd, spec$lower %||% -Inf, spec$upper %||% Inf),
    lognormal  = function(u) {
      p <- if (!is.null(spec$mean)) lnorm_par(mean = spec$mean, sd = spec$sd)
           else lnorm_par(median = spec$median, p90 = spec$p90)
      (spec$shift %||% 0) + qlnorm(u, p[["meanlog"]], p[["sdlog"]])
    },
    uniform    = function(u) spec$min + (spec$max - spec$min) * u,
    triangular = function(u) q_triangular(u, spec$min, spec$mode, spec$max),
    pert       = function(u) q_pert(u, spec$min, spec$mode, spec$max, spec$lambda %||% 4),
    bernoulli  = function(u) as.numeric(u < spec$p),
    discrete   = function(u) q_discrete(u, unlist(spec$values), unlist(spec$probs)),
    empirical  = function(u) q_empirical(u, unlist(spec$data)),
    stop("Unbekannte Verteilung: ", spec$dist))
}

# Schnelle tabellierte Quantilfunktion (für große N x T, z. B. qbeta)
tabulate_qf <- function(qf, m = 4096) {
  g <- c(0, pnorm(seq(-7, 7, length.out = m)), 1)   # Stützstellen in den Rändern verdichtet
  approxfun(g, qf(g), rule = 2)
}
```

### 2.2 Zeitreihenprozesse (ein Pfad je Simulation)

Die Zeitachse ist jährlich (Δt = 1), passend zur VoFi-Konvention mit nachschüssigen Jahreszahlungen. Für jeden Prozess entsteht eine Matrix standardnormaler Schocks $Z$ (N×T), gegebenenfalls über Prozesse hinweg korreliert (Abschnitt 3.4). Die Schleife über t ist kurz (T ≤ 80), jede Iteration ist eine Vektoroperation über N.

**(a) Geometrische Brownsche Bewegung (GBM), Random Walk im Log-Preis**

$$\ln P_t = \ln P_{t-1} + \ln(1+g) - \tfrac{1}{2}\sigma^2 + \sigma\,\varepsilon_t \quad\Rightarrow\quad E[P_t] = P_0(1+g)^t,\;\; \text{Median}(P_t) = P_0(1+g)^t e^{-\sigma^2 t/2}$$

Parametrisiert wird über die erwartete Wachstumsrate g, nicht über die Log-Drift. Über lange Horizonte wird die GBM sehr breit: Mit σ = 15 % und T = 40 gilt P95/P50 = exp(1,645 · 0,15 · √40) ≈ 4,8. Für Energiepreise ist sie deshalb **nicht der Default**, sondern nur Option.

**(b) AR(1) auf Wachstumsraten** (Inflation, Miete, Baupreise)

$$g_t = \mu + \varphi\,(g_{t-1} - \mu) + \sigma_\varepsilon\,\varepsilon_t,\qquad I_t = I_{t-1}(1+g_t)$$

Stationär gilt $E[g] = \mu$, $Var[g] = \sigma_\varepsilon^2/(1-\varphi^2)$ und $Corr(g_t, g_{t-k}) = \varphi^k$. Für die kumulierte Wachstumsrate über h Jahre gilt näherungsweise $sd(\sum g) \approx \sigma_\varepsilon\sqrt{h}/(1-\varphi)$. Persistente Schocks verbreitern die Langfristunsicherheit deutlich: Mit φ = 0,6 und σ_ε = 1 Pp. ergibt sich über 40 Jahre etwa ±16 Pp. kumuliert.

Die Variante **`linked_ar1`** bildet eine strukturelle Kopplung ab: $g_t = a + b\,\pi_t + u_t$ mit einem eigenen AR(1)-Rest $u_t$, z. B. Miete oder Baupreis an der Inflation $\pi_t$.

**(c) Random Walk in Wachstumsraten (nur mit Warnung)**

$g_t = g_{t-1} + \sigma\varepsilon_t$ hat die Varianz $Var(g_t) = t\sigma^2$, und die Varianz des kumulierten Niveaus wächst mit ~t³. Über 40–80 Jahre explodiert das. Das Tool bietet den Prozess höchstens mit Schranken (`lower`/`upper`) und mit einer Warnung an.

**(d) Ornstein-Uhlenbeck / Vasicek für Zinsen (exakte Diskretisierung)**

$$r_t = \theta + (r_{t-1} - \theta)\,e^{-\kappa\Delta} + \sigma\sqrt{\tfrac{1 - e^{-2\kappa\Delta}}{2\kappa}}\;\varepsilon_t$$

Es gilt $E[r_t \mid r_0] = \theta + (r_0-\theta)e^{-\kappa t}$, die stationäre Varianz ist $\sigma^2/(2\kappa)$ und die Halbwertszeit $\ln 2/\kappa$. Die Abbildung auf ein AR(1) lautet $\varphi = e^{-\kappa\Delta}$ und $\sigma_\varepsilon = \sigma\sqrt{(1-\varphi^2)/(2\kappa)}$. Die Euler-Diskretisierung ist nicht nötig, weil die exakte Form gleich wenig kostet.

**Floor:** Der latente Zustand $r_t$ bleibt unbegrenzt, nur der beobachtete Zins wird begrenzt: $\tilde r_t = \max(r_t, r_{min})$. Eine Reflexion des Zustands würde die Mean-Reversion-Statistik verzerren. Wer strikt positive Zinsen mit niveauabhängiger Volatilität braucht, nimmt ein verschobenes Black-Karasinski-Modell (OU auf $\ln(r_t - s)$) als Option. CIR wird nicht empfohlen.

**(e) Mean Reversion um einen Trend** (Schwartz-1-Faktor-Logik, Default für Energiepreise)

$$\ln P_t = \ln \mathrm{Trend}_t + y_t - \tfrac{1}{2}v_t,\quad y_t = \varphi\,y_{t-1} + \sigma\varepsilon_t,\quad v_t = \varphi^2 v_{t-1} + \sigma^2,\quad y_0 = v_0 = 0$$

Damit gilt $E[P_t] = \mathrm{Trend}_t = P_0(1+g)^t$. Das Trendwachstum g darf verteilt sein (S→P). Im Prototyp ist die Trendunsicherheit nach 40 Jahren die dominante Komponente: g ~ N(2 %; 1 Pp.) erzeugt einen Variationskoeffizienten des Gaspreises in T = 40 von rund 43 %. Die AR(1)-Abweichung allein (φ = 0,75, σ = 8 %) bringt stationär nur rund 12 %. **Für Investitionsentscheidungen ist Unsicherheit über den Trend meist wichtiger als die Volatilität von Jahr zu Jahr.**

**(f) Szenario-Mischung** (CO₂-Preis, Förderpolitik, Regulierung)

$S \sim \text{Kategorial}(p_1, \dots, p_K)$ wird je Simulation über eine eigene Basiszahl u gezogen. Dann gilt $X_t = x^{(S)}_t \cdot \exp(y_t - v_t/2)$ mit einem optionalen AR(1)-Log-Rauschen wie in (e). Die Szenariopfade $x^{(k)}_t$ werden aus Stützstellen (Jahr, Wert) linear interpoliert. Der Szenarioindex wird gespeichert, damit das Tool bedingte Auswertungen erstellen kann (Ergebnisse je CO₂-Szenario).

**(g) `iid`**: Jahresweise unabhängige Ziehungen aus einer statischen Verteilung (z. B. Leerstandsschwankung, Witterung). Sie werden über eine tabellierte Quantilfunktion angewendet.

**(h) Bootstrap aus historischen Reihen** (Option)

Zirkulärer Moving-Block-Bootstrap (Künsch 1989) mit Blocklänge b ≈ H^{1/3} (bei rund 30 Jahresbeobachtungen also b = 3–4). Mehrere Reihen werden **mit denselben Jahresindizes** gezogen. Dadurch bleiben die Kreuzkorrelation und die Autokorrelation innerhalb der Blöcke erhalten, ohne dass eine Korrelationsmatrix nötig ist. Optional wird die Reihe neu zentriert: $g^* = g - \bar g + \mu_{Ziel}$. Alternative ist der stationäre Bootstrap (Politis/Romano 1994) mit geometrisch verteilten Blocklängen. Vorbehalt: Die Historie (z. B. 1996–2025 mit Niedrigzinsphase und Energiekrise 2022) ist nicht repräsentativ für die nächsten 40 Jahre. Der Bootstrap ist deshalb Option, nicht Default.

**(i) `fixed_path`**: deterministischer Pfad aus Stützstellen, z. B. für Stresstests („Zins +3 Pp. zum Reset“). Er wird als 1×T-Matrix gespeichert und vom Rechenkern automatisch auf N verteilt (Abschnitt 5.5).

**Parameterunsicherheit (hierarchisch):** Jeder numerische Prozessparameter darf statt einer Zahl eine Verteilung sein, z. B. `mu: {dist: normal, mean: 0.02, sd: 0.003}`. Der Sampler zieht ihn als statischen Parameter (Name `prozess.param`, z. B. `inflation.mu`). Er kann damit an Parameter-Korrelationen teilnehmen und erscheint in der Sensitivitätsanalyse.

```r
correlate_shocks <- function(Zlist, R) {           # Liste von N x T-Matrizen -> korreliert
  U <- chol(near_pd_corr(R)); N <- nrow(Zlist[[1]]); T <- ncol(Zlist[[1]])
  M <- vapply(Zlist, as.vector, numeric(N * T)) %*% U   # (N*T) x m
  setNames(lapply(seq_along(Zlist), function(j) matrix(M[, j], N, T)), names(Zlist))
}
sim_ar1 <- function(Z, mu, phi, sigma, x0 = mu) {   # mu, x0 dürfen Vektoren der Länge N sein
  X <- matrix(0, nrow(Z), ncol(Z)); x <- rep_len(x0, nrow(Z))
  for (t in seq_len(ncol(Z))) { x <- mu + phi * (x - mu) + sigma * Z[, t]; X[, t] <- x }
  X
}
sim_vasicek <- function(Z, r0, theta, kappa, sigma, floor = -Inf, dt = 1) {
  a <- exp(-kappa * dt); s <- sigma * sqrt((1 - a^2) / (2 * kappa))
  X <- matrix(0, nrow(Z), ncol(Z)); r <- rep_len(r0, nrow(Z))
  for (t in seq_len(ncol(Z))) { r <- theta + (r - theta) * a + s * Z[, t]; X[, t] <- r }
  pmax(X, floor)                                    # Floor nur auf der Ausgabe
}
sim_gbm <- function(Z, p0, g, sigma) {              # E[P_t] = p0 (1+g)^t
  incr <- log1p(g) - sigma^2 / 2 + sigma * Z
  p0 * exp(t(apply(incr, 1, cumsum)))
}
ar1_lognoise <- function(Z, phi, sigma) {           # exp(y_t - v_t/2) mit E = 1
  N <- nrow(Z); y <- numeric(N); v <- 0; X <- matrix(0, N, ncol(Z))
  for (t in seq_len(ncol(Z))) {
    y <- phi * y + sigma * Z[, t]; v <- phi^2 * v + sigma^2; X[, t] <- exp(y - v / 2)
  }
  X
}
sim_mr_trend <- function(Z, trend, phi, sigma) {    # trend: Vektor (T) oder Matrix (N x T)
  if (is.matrix(trend)) trend * ar1_lognoise(Z, phi, sigma)
  else sweep(ar1_lognoise(Z, phi, sigma), 2, trend, `*`)
}
sim_scenario_mix <- function(u, paths, probs, Z = NULL, sigma = 0, phi = 0) {
  s <- q_discrete(u, seq_len(nrow(paths)), probs)   # Szenarioindex je Simulation
  X <- paths[s, , drop = FALSE]
  if (!is.null(Z) && sigma > 0) X <- X * ar1_lognoise(Z, phi, sigma)
  attr(X, "scenario") <- s
  X
}
sim_iid <- function(U, qf) matrix(qf(as.vector(U)), nrow(U), ncol(U))
sim_block_bootstrap <- function(hist, n, T, block = 3, seed, name = "bootstrap", recenter = NULL) {
  hist <- as.matrix(hist); H <- nrow(hist); nb <- ceiling(T / block)
  starts <- with_stream(seed, name, matrix(sample.int(H, n * nb, replace = TRUE), n, nb))
  idx <- (outer(starts, 0:(block - 1), "+") - 1) %% H + 1          # zirkulär
  idx <- aperm(idx, c(1, 3, 2)); dim(idx) <- c(n, nb * block)
  idx <- idx[, seq_len(T), drop = FALSE]
  out <- lapply(seq_len(ncol(hist)), function(j) {                   # gleiche Jahre für alle Reihen
    x <- hist[, j]; if (!is.null(recenter)) x <- x - mean(x) + recenter[j]
    matrix(x[idx], n, T)
  })
  setNames(out, colnames(hist))
}
```

Geprüft im Prototyp (N = 20.000): AR(1)-Stationär-sd 0,0124 (theoretisch 0,0125), Lag-1-Autokorrelation 0,59 (Soll 0,6). Vasicek: E[r₁₀] 3,614 % (theoretisch 3,612 %), Floor eingehalten. GBM: E[P₄₀]/P₀ = 2,19 (theoretisch 2,21). Mean-Reversion um den Trend: E[P_T]/Trend_T = 0,9997.

### 2.3 Kalibrierung der Defaults

**Vorgehen:**

1. **Datenbasierte Volatilität und Persistenz, expertengesetzte Langfristniveaus.** σ, φ und κ lassen sich aus der Historie schätzen. Die Langfristniveaus (θ, μ, Trend) sind vor allem eine Erwartung über die Zukunft (EZB-Ziel, Forward-Kurve, Konsens) und sollten nicht naiv als Stichprobenmittel übernommen werden.
2. **Unsicherheit über das Langfristniveau explizit als Parameterunsicherheit** modellieren (S→P), statt σ künstlich zu erhöhen.
3. **Jahresdurchschnitte als Kalibrierbasis** passen zu jährlichen Zahlungsströmen (die Jahresenergiekosten folgen dem Durchschnittspreis). Ausnahme: Die Anschlussfinanzierung wird zu einem Zeitpunkt fixiert, deshalb ist hier die Punkt-Volatilität maßgeblich (σ eher etwas höher ansetzen).
4. **Jede Default-Datei bekommt Metadaten** (Quelle, Reihe, Zeitraum, Abrufdatum, Schätzmethode, Bearbeiter). Das Tool liefert dazu `calibrate_ar1()` und `calibrate_vasicek()` mit, damit Nutzer mit eigenen Reihen nachkalibrieren können.

```r
calibrate_ar1 <- function(x) {                       # OLS: x_t = a + phi x_{t-1} + e
  fit <- lm(x[-1] ~ x[-length(x)])
  a <- coef(fit)[[1]]; phi <- coef(fit)[[2]]; s <- sd(residuals(fit))
  c(mu = a / (1 - phi), phi = phi, sigma_e = s, sd_stationary = s / sqrt(1 - phi^2))
}
calibrate_vasicek <- function(r, dt = 1) {
  p <- calibrate_ar1(r); b <- p[["phi"]]; kappa <- -log(b) / dt
  c(theta = p[["mu"]], kappa = kappa, sigma = p[["sigma_e"]] * sqrt(2 * kappa / (1 - b^2)),
    half_life = log(2) / kappa)
}
```

**Eigene Auswertung öffentlicher Reihen** (am 25.10.2026 abgerufen, Rechnung im Prototyp):

| Reihe | Zeitraum | Ergebnis | Vorschlag Default |
|---|---|---|---|
| **Bundesbank SUD119**: Effektivzinssatz Neugeschäft, Wohnungsbaukredite an private Haushalte, anfängliche Zinsbindung > 10 J. (BBIM1.M.DE.B.A2C.P.R.A.2250.EUR.N) | 01/2003–08/2026 | Jahresmittel 1,22 % (2020) bis 5,08 % (2003), Mittel 2003–2025 3,29 %; aktuell 4,04 % (08/2026, vorläufig). Vasicek-OLS auf Jahresmitteln: θ 2,74 %, κ 0,13, σ 0,54 Pp., Halbwertszeit 5,3 J. Auf Monatsdaten: θ 2,66 %, κ 0,089, σ 0,37 Pp. p. a. sd der 12-Monats-Änderungen 0,60 Pp. | r₀ = aktueller Wert, **θ 3,75 %** (Experte; das Stichprobenmittel ist durch die Niedrigzinsphase verzerrt), **κ 0,12, σ 0,7 Pp.**, Floor 0,5 %; Option θ ~ N(3,75 %; 0,5 Pp.) |
| **HVPI Deutschland** (EZB ICP, Jahresrate, Jahresmittel) | 1997–2025 | Mittel 1,9 %, sd 1,7 Pp.; AR(1): μ 2,02 %, φ 0,55, σ_ε 1,43 Pp. Nur bis 2019: μ 1,46 %, φ 0,23, σ_ε 0,67 Pp. (die Parameter hängen stark vom Regime ab) | **μ ~ N(2,0 %; 0,4 Pp.), φ 0,5, σ_ε 1,0–1,2 Pp.** |
| **HVPI-Teilindizes DE** (Log-Jahreswachstum der Jahresmittel) | 1997–2025 | Strom 3,5 % p. a. (sd 4,8 Pp.), Gas 4,5 % (sd 9,8), Heizöl 3,7 % (sd 20,7), Fernwärme 4,7 % (sd 8,2), tatsächliche Mietzahlungen 1,4 % (sd 0,4; AR 0,58). Realer Log-Preis um linearen Trend: Strom φ 0,75 / σ_ε 3,8 %; Gas φ 0,79 / σ_ε 8,1 %; Heizöl φ 0,70 / σ_ε 18,3 %; realer Trend jeweils ≈ +2 % p. a. (enthält EEG, Ökosteuer, BEHG, also keine Prognose) | `mr_trend`: Gas φ 0,75, σ 8 %; Strom φ 0,75, σ 4 %; Öl φ 0,7, σ 18 %; Trend nominal N(2 %; 1 Pp.) |
| **Korrelation der Jahreswachstumsraten** (HVPI-Teilindizes) | 1997–2025 | VPI–Gas 0,78; VPI–Strom 0,60; Gas–Strom 0,54; Gas–Fernwärme 0,72; VPI–Miete 0,32; Strom–Miete −0,15 | Schockkorrelation VPI–Gas 0,6, Gas–Strom 0,5, VPI–Miete über die Kopplung b |
| **Baupreise Wohngebäude DE** (Eurostat sts_copi_a, PRC_PRR, Destatis-basiert) | 1997–2025 | Mittel 2,68 %, sd 3,39 Pp.; AR(1): μ 3,05 %, φ 0,65, σ_ε 2,5 Pp. Korrelation mit HVPI 0,88; mittlere Prämie über HVPI 0,73 Pp. Regression: g = −0,7 Pp. + 1,74·π (Rest-sd 1,6 Pp., AR 0,69) | `linked_ar1`: **a 0,7 Pp., b 1,0 (bis 1,5), φ 0,65, σ 1,5 Pp.** |

Den CO₂-Preis schätzt das Tool nicht aus Daten, sondern legt ihn als Szenarien fest. Stand Oktober 2026: Für 2026 gilt ein Preiskorridor von 55–65 €/t. Für 2027 sieht ein Gesetzentwurf (3. BEHG-Änderungsgesetz) ebenfalls 55–65 €/t vor, weil der EU-ETS 2 auf 2028 verschoben wurde. Ob das Gesetz verkündet ist, war nicht bestätigt. Für 2030 reichen die Prognosen von etwa 100 €/t (Analystenumfrage) bis rund 200–275 €/t (Ariadne-Modellrechnungen für die ESR-Sektoren, Bandbreite 140–405 €/t). Die Szenariodefaults in Abschnitt 10 sind Platzhalter, die Wahrscheinlichkeiten muss der Nutzer festlegen.

---

## 3. Abhängigkeiten

### 3.1 Wo Abhängigkeiten nötig sind

| Paar | Art | Empfohlene Umsetzung |
|---|---|---|
| Baukostenüberschreitung ↔ Bauzeitverzug | statisch–statisch | Rangkorrelation ρ_S ≈ 0,5 (Iman–Conover) |
| Prebound f_pre ↔ f_post (Nutzerverhalten) | statisch–statisch | ρ_S ≈ 0,3 |
| Langfristniveau Inflation (μ) ↔ Zinsniveau (θ) | Parameterunsicherheit | ρ_S ≈ 0,5, über die Parameter-Korrelation, weil beide als S→P gezogen werden |
| Inflation ↔ Bauzins, Gas, Baupreise (Jahresschocks) | Prozess–Prozess | Schockkorrelation 0,4 / 0,6 / über Kopplung |
| Gas ↔ Strom ↔ Fernwärme | Prozess–Prozess | Schockkorrelation 0,5–0,7 |
| Miete ↔ Inflation, Baupreis ↔ Inflation | Prozess–Prozess | **strukturell** (`linked_ar1`), nicht über Korrelation |
| Exit-Rendite ↔ Zins in T | statisch–Prozess | **strukturell**: y_exit = y₀ + β(r_T − r₀) + ε |
| Haben-/Kontokorrentzins ↔ Bauzins | Prozess–Prozess | **strukturell** (Spread) |
| Vermieteranteil CO₂ ↔ tatsächlicher Verbrauch | Modell | **strukturell** (Stufenmodell auf dem stochastischen Verbrauch) |

**Doppelzählung vermeiden:** Ist die Miete über b·π an die Inflation gekoppelt, kommt eine zusätzliche Schockkorrelation Miete–Inflation obendrauf. Die Validierung sollte die resultierende Korrelation der Wachstumsraten ausgeben.

### 3.2 Gauß-Copula mit Cholesky

Unabhängige Basiszahlen $U$ (N×k) werden mit $Z = \Phi^{-1}(U)\,\mathbf{U}_R$ transformiert, wobei $R = \mathbf{U}_R^\top\mathbf{U}_R$ die Cholesky-Zerlegung mit oberer Dreiecksmatrix ist (`chol()` in R, Zeilenvektor-Konvention). Danach gilt $U' = \Phi(Z)$ und $x_j = F_j^{-1}(U'_j)$.

- **Nutzer geben Rangkorrelationen (Spearman) an.** Sie sind invariant unter monotonen Transformationen und deshalb für beliebige Randverteilungen sinnvoll. Für die Gauß-Copula gilt $\rho_S = \frac{6}{\pi}\arcsin(\rho/2)$, also $\rho = 2\sin(\pi\rho_S/6)$, und für Kendall $\tau = \frac{2}{\pi}\arcsin\rho$. Die Abweichung ist klein: bei ρ_S = 0,5 ist ρ = 0,518. Das Tool rechnet sie trotzdem um. Im Prototyp ergaben sich mit Umrechnung Spearman-Werte von 0,495/0,298/0,599 bei Ziel 0,5/0,3/0,6.
- **Schwächen:** Die Gauß-Copula hat keine Tail-Abhängigkeit und unterschätzt gemeinsame Extreme (2022: Energiepreise, Inflation und Zinsen gleichzeitig). Für Stressanalysen eignet sich eine t-Copula als Option für v2: $Z/\sqrt{W/\nu}$ mit einem gemeinsamen $W \sim \chi^2_\nu$ je Zeile und ν = 4–5. Außerdem zerstört die Copula-Transformation die LHS-Schichtung in den korrelierten Spalten teilweise: Im Prototyp waren danach nur noch 12.617 von 20.000 Schichten belegt.

### 3.3 Reparatur nicht positiv definiter Matrizen

Paarweise eingegebene Korrelationen ergeben oft eine nicht positiv semidefinite Matrix. Ein Beispiel ist (0,9; −0,6; 0,2) mit Eigenwert −0,18. Das Tool bietet zwei Verfahren an:

1. **Eigenwert-Clipping** (Base R, Default): Eigenwerte auf ε ≥ 10⁻⁶ setzen, zurücktransformieren und auf Einheitsdiagonale reskalieren.
2. **Higham (2002)**, nächstgelegene Korrelationsmatrix in der Frobenius-Norm: `Matrix::nearPD(R, corr = TRUE)`. Das Paket `Matrix` gehört zu den Recommended Packages und ist installiert.

Im Beispiel liefert das Clipping (0,772; −0,516; 0,146), Higham (0,784; −0,516; 0,127). **Das Tool warnt, sobald |ΔR| > 0,05 ist**, und protokolliert die reparierte Matrix im Ergebnis.

### 3.4 Iman–Conover (Rangkorrelation bei exakt erhaltenen Rändern)

Algorithmus nach Iman/Conover (1982), angewendet je LHS-Replikat:

1. Scores $a_i = \Phi^{-1}(i/(m+1))$ (van der Waerden). Daraus entsteht eine Score-Matrix $S$ (m×k), deren Spalten unabhängig zufällig permutiert sind.
2. $E = \text{cor}(S)$ mit $E = Q^\top Q$; die Zielmatrix (Pearson-umgerechnet) ist $C = P^\top P$.
3. $T = S\,Q^{-1}P$; die Stichprobenkorrelation von T entspricht dann exakt C.
4. Jede Spalte von $X$ wird so umsortiert, dass ihre Ränge den Rängen der entsprechenden Spalte von $T$ folgen.

**Vorteile:** Die Randverteilungen, also die Stichprobenwerte selbst, bleiben **exakt** erhalten, und damit auch die LHS-Schichtung. Iman–Conover funktioniert mit beliebigen Verteilungen. Im Prototyp lag die Rangkorrelation bei 0,501/0,298/0,600 (Ziel 0,5/0,3/0,6), die sortierten Werte waren identisch. **Grenze:** Bei stark diskreten Rändern (Bernoulli) wird die Zielkorrelation wegen der Bindungen nicht erreicht. Das gilt für jede Rangmethode, und das Tool sollte darauf hinweisen.

```r
spearman_to_pearson <- function(rs) 2 * sin(pi * rs / 6)

near_pd_corr <- function(R, eps = 1e-6) {          # Eigenwert-Clipping + Reskalierung
  R <- (R + t(R)) / 2
  e <- eigen(R, symmetric = TRUE)
  if (min(e$values) >= eps) return(R)
  R2 <- e$vectors %*% diag(pmax(e$values, eps)) %*% t(e$vectors)
  d <- sqrt(diag(R2)); R2 <- R2 / outer(d, d)
  dimnames(R2) <- dimnames(R)
  R2
}
gauss_copula <- function(U, R_spearman) {          # U unabhängig -> U korreliert
  R <- near_pd_corr(spearman_to_pearson(R_spearman)); diag(R) <- 1
  pnorm(qnorm(U) %*% chol(R))
}
iman_conover <- function(X, R_spearman, seed, name = "iman_conover", replicates = 1L) {
  C <- near_pd_corr(spearman_to_pearson(R_spearman)); diag(C) <- 1
  P <- chol(C); k <- ncol(X); m <- nrow(X) %/% replicates
  for (b in seq_len(replicates)) {                 # je LHS-Replikat getrennt!
    ix <- (b - 1) * m + seq_len(m)
    a  <- qnorm(seq_len(m) / (m + 1))              # van-der-Waerden-Scores
    S  <- with_stream(seed, paste0(name, ":", b),
                      vapply(seq_len(k), function(j) sample(a), numeric(m)))
    Tm <- S %*% backsolve(chol(cor(S)), diag(k)) %*% P   # S Q^{-1} P
    for (j in seq_len(k)) X[ix, j] <- sort(X[ix, j])[rank(Tm[, j], ties.method = "first")]
  }
  X
}
```

### 3.5 Serielle Korrelation und Kreuzkorrelation von Prozessschocks

- **Seriell**: über φ (AR(1)) bzw. κ (Vasicek) innerhalb jedes Prozesses. Statische Parameter haben per Definition keine serielle Struktur.
- **Kreuzkorrelation**: Je Periode t werden die Schocks aller m Prozesse als $\boldsymbol\varepsilon_t = \mathbf{Z}_t\,\mathbf{U}_\varepsilon$ korreliert (zeithomogen, dieselbe Matrix für alle t). Effizient geht das als eine Matrixmultiplikation über alle (N·T) Zeilen (siehe `correlate_shocks`). Im Prototyp lag die Schockkorrelation bei 0,499 (Ziel 0,5).
- **Schock- und Niveaukorrelation unterscheiden sich.** Für zwei AR(1)-Prozesse mit Schockkorrelation ρ_ε gilt stationär
  $$Corr(x_1, x_2) = \rho_\varepsilon\,\frac{\sqrt{(1-\varphi_1^2)(1-\varphi_2^2)}}{1 - \varphi_1\varphi_2}.$$
  Beispiel φ₁ = 0,9, φ₂ = 0,3, ρ_ε = 0,5: Die Niveaukorrelation beträgt 0,285 (Prototyp 0,282). Empirische Korrelationen schätzt man deshalb auf den **Schocks bzw. Residuen** und nicht auf den Niveaus. Zwei unabhängige Random Walks zeigen in Niveaus Scheinkorrelationen.
- **Statische Parameter mit Prozessen koppeln**: bevorzugt strukturell (Exit-Rendite ~ r_T). Alternativ nehmen Prozessparameter (μ, θ, Trend) an der Parameter-Copula teil.

---

## 4. Stichprobenverfahren, Reproduzierbarkeit und Konvergenz

### 4.1 Pseudo-Zufallszahlen und Latin Hypercube Sampling

- **Pseudo**: Mersenne-Twister mit explizit fixierten Varianten: `set.seed(seed, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")`. Seit R 3.6.0 hat sich `sample.kind` geändert; nur explizites Setzen schützt vor Ergebnisänderungen nach R-Updates.
- **LHS** (McKay/Beckman/Conover 1979) für k Größen: $U_{ij} = (\pi_j(i) - V_{ij})/N$ mit einer zufälligen Permutation $\pi_j$ von 1…N und $V_{ij} \sim U(0,1)$. Jede Randverteilung ist damit exakt geschichtet: In jedem der N gleich wahrscheinlichen Intervalle liegt genau ein Wert. Die Variante „centered LHS“ ($(\pi - 0{,}5)/N$) ist deterministisch innerhalb der Schichten und erschwert die Fehlerschätzung; sie wird nicht empfohlen.
- **Replizierte LHS** (Default, r = 10 Blöcke à N/r): Die Blöcke sind unabhängige LHS-Designs. Den Standardfehler eines Schätzers liefert die Streuung der Blockschätzer: $SE = sd(\hat\theta_1, \dots, \hat\theta_r)/\sqrt r$.
- **Prozessschocks**: LHS je Perioden-Spalte (kostet fast nichts). Die anschließende Cholesky-Korrelation zerstört die Schichtung teilweise; das ist akzeptabel.
- **Quasi-Monte-Carlo** (Sobol, Halton) kommt nicht in v1: Es ist kein Paket installiert, und bei 200–400 Dimensionen (T × Prozesse) sinkt der Nutzen.

**Gemessener Effekt im Prototyp** (100 unabhängige Wiederholungen mit je n = 1.000; Standardabweichung der Schätzer, Varianzreduktion gegenüber Pseudo):

| Schätzer | Pseudo | LHS (1 Block) | LHS (10 Replikate) | Antithetisch |
|---|---|---|---|---|
| Mittelwert Endwert | 104.000 € | 27.000 € (**×14,8**) | 30.600 € (**×11,5**) | 46.800 € (×4,9) |
| 5-%-Quantil Endwert | 331.000 € | 268.000 € (×1,5) | 245.000 € (×1,8) | 315.000 € (×1,1) |
| Median Endwert | 102.000 € | 67.800 € (×2,3) | 72.200 € (×2,0) | 55.100 € (×3,4) |
| P(Endwert < Opportunität) | 0,0046 | 0,0035 (×1,7) | 0,0034 (×1,8) | 0,0043 (×1,1) |
| P(min DSCR < 1) | 0,0165 | 0,0038 (×18,9) | 0,0042 (×15,6) | 0,0051 (×10,3) |

Die Ergebnisse lassen sich so lesen: Bei Mittelwerten und bei Wahrscheinlichkeiten, die von statischen Größen getrieben werden (hier Bauzeitverzug → DSCR im ersten Jahr), spart LHS den Faktor 10 bis 19 an Rechenläufen. Bei Tail-Quantilen ist der Gewinn klein (×1,5–1,8). Die Replikation kostet kaum Effizienz.

### 4.2 Antithetische Variablen

Zu jeder Basiszahl u bzw. jedem Schock ε wird auch 1 − u bzw. −ε verwendet. Das wirkt gut bei monotonen Zielgrößen. **Den Standardfehler muss das Tool auf Paarbasis schätzen** (erst das Paarmittel bilden, dann die Streuung über N/2 Paare). Für Quantile bringen antithetische Variablen wenig und erschweren die Fehlerschätzung; mit LHS kombiniert man sie nicht sinnvoll. Deshalb sind sie **Option, Default aus**.

### 4.3 Reproduzierbarkeit: benannte Zufallsströme

Ein globaler Zufallsstrom, der alle Größen nacheinander zieht, hat einen Nachteil: Ein zusätzlicher Parameter in der YAML-Datei verschiebt alle folgenden Ziehungen. Das empfohlene Verfahren lautet:

$$\text{seed}_j = (\text{seed} \cdot 1000003 + h(\text{name}_j)) \bmod (2^{31}-1)$$

Dabei ist h ein Polynom-Hash des Namens, der in double-Arithmetik exakt bleibt. Jede Größe zieht ihre N Werte (bzw. N×T Schocks) aus einem eigenen Strom (`par:<name>`, `shock:<name>`, `scen:<name>`, `ic:<gruppe>:<block>`). Der globale RNG-Zustand des Nutzers bleibt unberührt.

**Eigenschaften (im Prototyp getestet):**

- gleicher Seed → identisches Szenarioobjekt
- zusätzlicher Parameter → alle anderen Ziehungen unverändert
- Reihenfolge in der YAML-Datei egal
- CRN über Varianten automatisch (Abschnitt 8)

Eine Änderung von N verändert die Ziehungen; das ist bei LHS unvermeidbar.

```r
stream_hash <- function(name) {                 # Polynom-Hash mod (2^31 - 1), exakt in double
  h <- 0
  for (code in utf8ToInt(name)) h <- (h * 131 + code) %% 2147483647
  h
}
with_stream <- function(seed, name, expr) {     # eigener RNG-Zustand, globaler Zustand bleibt unberührt
  had <- exists(".Random.seed", envir = globalenv())
  if (had) old <- get(".Random.seed", envir = globalenv())
  old_kind <- RNGkind()
  on.exit({
    RNGkind(old_kind[1], old_kind[2], old_kind[3])
    if (had) assign(".Random.seed", old, envir = globalenv())
    else if (exists(".Random.seed", envir = globalenv())) rm(".Random.seed", envir = globalenv())
  })
  set.seed((seed * 1000003 + stream_hash(name)) %% 2147483647,
           kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
  force(expr)
}
lhs_vector <- function(n, replicates = 1L) {    # replizierte LHS: r unabhängige Blöcke à n/r
  m <- n %/% replicates
  stopifnot(m * replicates == n)
  unlist(lapply(seq_len(replicates), function(b) (sample.int(m) - runif(m)) / m))
}
draw_u <- function(n, seed, name, method = c("pseudo", "lhs"), antithetic = FALSE, replicates = 1L) {
  method <- match.arg(method)
  with_stream(seed, name, {
    m <- if (antithetic) n %/% 2 else n
    u <- if (method == "lhs") lhs_vector(m, replicates) else runif(m)
    if (antithetic) c(u, 1 - u) else u
  })
}
draw_shocks <- function(n, T, seed, name, method = "pseudo", antithetic = FALSE, replicates = 1L) {
  with_stream(seed, paste0("shock:", name), {
    m <- if (antithetic) n %/% 2 else n
    Z <- if (method == "lhs") vapply(seq_len(T), function(t) qnorm(lhs_vector(m, replicates)), numeric(m))
         else matrix(rnorm(m * T), m, T)
    if (antithetic) rbind(Z, -Z) else Z
  })
}
```

**Parallelität:** Das Sampling ist schnell (0,5–0,8 s für N = 10.000) und läuft **zentral** im Hauptprozess. Parallelisiert wird, falls überhaupt, nur die Auswertung von Chunks oder Varianten. Das Ergebnis hängt dann nicht von der Anzahl der Worker ab. Erzeugen die Worker später doch selbst Zufallszahlen (sehr große N, Pseudo-Modus), gilt: `RNGkind("L'Ecuyer-CMRG")`, je **Chunk fester Größe** (nicht je Worker) ein Strom über `parallel::nextRNGStream()`, bzw. `future.apply::future_lapply(..., future.seed = TRUE)`.

**Metadaten im Ergebnisobjekt:**

- Seed, Sampling-Verfahren, Anzahl Replikate und N
- RNG-Varianten
- R- und Paketversion
- Hash der Spezifikation (z. B. über `serialize` + eigener Hash), Zeitstempel
- reparierte Korrelationsmatrizen

### 4.4 Anzahl der Läufe und Konvergenzdiagnostik

**Faustformeln** für das 95-%-Niveau:

- Mittelwert mit relativer Halbbreite e: $N = (1{,}96\,CV/e)^2$. Mit CV = 0,5 und e = 1 % ergibt sich N ≈ 9.600, mit LHS etwa um den Faktor 10 weniger.
- Wahrscheinlichkeit p mit absoluter Halbbreite h: $N = 1{,}96^2\,p(1-p)/h^2$. Beispiele: p = 0,10, h = 1 Pp. → N ≈ 3.460; p = 0,05, h = 0,5 Pp. → N ≈ 7.300.
- Quantil $q_p$: verteilungsfreies Konfidenzintervall über Ordnungsstatistiken mit den Indizes $k_{lo} = F^{-1}_{Bin(N,p)}(0{,}025)$ und $k_{hi} = F^{-1}_{Bin(N,p)}(0{,}975) + 1$. Für das P5 bei N = 10.000 liegen etwa 500 Beobachtungen im Tail.
- CVaR: Der Standardfehler kommt aus den Replikaten oder aus einem Bootstrap. Der CVaR braucht deutlich mehr Läufe: Im Prototyp schwankte der CVaR₅ % der Endwertdifferenz zwischen zwei Läufen mit N = 10.000 zwischen −65 T€ und +74 T€, weil der linke Rand sehr fett ist (Kontokorrent-Zinseszins in Extremszenarien).

**Wichtig bei LHS:** Die naive Formel $sd/\sqrt N$ **überschätzt** den Fehler stark. Im Prototyp (N = 10.000, 30 Wiederholungen) betrug die wahre Streuung des Mittelwerts 7.572 €. Der naive Standardfehler lag bei 32.208 € (4,3-fach zu hoch), der Replikat-Standardfehler bei 8.823 € (passend). **Das gilt aber nur, wenn Iman–Conover je Replikat angewendet wird.** Bei einer globalen Umsortierung ergab der Replikat-Standardfehler 20.344 € gegenüber einer wahren Streuung von 9.494 €, war also falsch.

**Defaults:** `n_sim` = 1.000 (Vorschau, Shiny live), 10.000 (Standard), 50.000 (Bericht, Tail-Kennzahlen); `replicates` = 10. **Stoppregel** (optional, nur Pseudo-Modus oder blockweise bei LHS): relative Halbbreite des Mittelwerts des Endwerts < 0,5 % **und** Halbbreite von P(Verlust) < 1 Pp.

**Diagnosegrafiken:**

- laufender Mittelwert mit 95-%-Band über logarithmisch verteilte Stützstellen (im Pseudo-Modus)
- Blockmittel über die Replikate (im LHS-Modus)
- laufende Quantile

**Ausweis:** In jedem Bericht steht der MC-Fehler neben der Kennzahl, z. B. „P(Verlust) = 1,8 % ± 0,3 Pp. (MC-Fehler)“, getrennt von der inhaltlichen Streuung.

```r
mc_convergence <- function(y, checkpoints = unique(round(10^seq(2, log10(length(y)), length.out = 25))),
                           probs = c(0.05, 0.5)) {
  cs <- cumsum(y); cs2 <- cumsum(y^2)
  do.call(rbind, lapply(checkpoints, function(n) {
    m <- cs[n] / n; s <- sqrt((cs2[n] - n * m^2) / (n - 1))
    q <- quantile(y[seq_len(n)], probs, names = FALSE)
    data.frame(n = n, mean = m, lo = m - 1.96 * s / sqrt(n), hi = m + 1.96 * s / sqrt(n),
               t(setNames(q, paste0("q", probs * 100))))
  }))
}
quantile_ci <- function(y, p, level = 0.95) {         # verteilungsfrei (Ordnungsstatistiken)
  n <- length(y); s <- sort(y); a <- (1 - level) / 2
  k <- qbinom(c(a, 1 - a), n, p)
  c(q = quantile(y, p, names = FALSE), lo = s[max(k[1], 1)], hi = s[min(k[2] + 1, n)])
}
se_replicates <- function(y, replicates, stat = mean) {   # ehrlicher SE bei replizierter LHS
  b <- rep(seq_len(replicates), each = length(y) / replicates)
  est <- tapply(y, b, stat); c(est = stat(y), se = sd(est) / sqrt(replicates))
}

# Konvergenzplot (ggplot2)
# ggplot(mc_convergence(k$endwert), aes(n, mean)) +
#   geom_ribbon(aes(ymin = lo, ymax = hi), alpha = .2) + geom_line() + scale_x_log10() +
#   labs(x = "Anzahl Simulationen", y = "Mittlerer Endwert (EUR)",
#        title = "Konvergenz des Mittelwerts mit 95-%-Konfidenzband")
```

---

## 5. Engine-Strategie

### 5.1 Prinzip: Schleife über t, Vektoren über N

Die VoFi ist eine Rekursion: Die Zinsen in t hängen von den Beständen in t − 1 ab, die Ausgleichsfinanzierung in t vom Finanzierungssaldo in t. Eine vollständige Vektorisierung über die Zeit ist deshalb nicht möglich. **Über die Simulationen ist die Rechnung dagegen vollständig unabhängig.** Die Engine hält jeden Zustand (Darlehensbestände, Kontokorrent, Geldanlage, Indizes) als Vektor der Länge N. Jede Periode ist eine Handvoll Vektoroperationen, und der Interpreter-Overhead von R fällt nur T-mal statt N·T-mal an.

**Regeln für den Engine-Code** (verbindlich, mit Code-Review und Test „N = 1 vs. vektorisiert“):

1. Jede Eingabe ist entweder skalar bzw. ein Vektor der Länge N (statisch) **oder** eine 1×T- bzw. N×T-Matrix (Pfad). Pfade werden nur über `x[, t]` gelesen; eine 1×T-Matrix liefert einen Skalar, den R automatisch auf N verteilt.
2. **Kein `if` auf simulierte Werte.** `if` ist nur auf t, auf Konfigurations-Flags und auf deterministische Termine erlaubt (z. B. das Ende der Zinsbindung, das für alle Läufe gleich ist). Für Wertlogik dienen `pmax`/`pmin`, Arithmetik mit logischen Masken (`x * (cond)`) oder maskierte Zuweisung (`x[m] <- y[m]`).
3. Keine `data.frame`-Operationen und keine wachsenden Objekte in der Schleife. Matrizen werden vorab angelegt, Kennzahlen nach der Schleife vektorisiert berechnet.
4. Zufall gibt es nur im Sampler. Die Engine ist rein deterministisch und bekommt das Szenarioobjekt übergeben.

### 5.2 Vektorisierte Ausgleichsregel

Grob-Standard: Ein Finanzierungsüberschuss tilgt zuerst das Kontokorrent, der Rest geht in die Geldanlage. Ein Fehlbetrag löst zuerst die Geldanlage auf, danach wird das Kontokorrent in Anspruch genommen. Zinsen fallen auf die Bestände der Vorperiode an. Weil Anlage und Kontokorrent nie gleichzeitig positiv sind, genügt eine Nettoposition:

```r
# pre: Saldo aller Zahlungen in t vor Ausgleich (Zahlungsreihe, EK, Darlehen, Zinsen auf Vorperiodenbestände)
net    <- pre + GA - KK                  # Nettoliquidität nach allen Zahlungen
GA_neu <- pmax(net, 0)                   # Überschuss -> Geldanlage
bedarf <- pmax(-net, 0)                  # Fehlbetrag
KK_neu <- pmin(bedarf, kk_limit)         # Kontokorrent bis zum Limit
nachschuss <- bedarf - KK_neu            # darüber: EK-Nachschuss = Liquiditätsengpass
kk_aufnahme <- pmax(KK_neu - KK, 0); kk_rueckf <- pmax(KK - KK_neu, 0)
ga_anlage   <- pmax(GA_neu - GA, 0); ga_aufl   <- pmax(GA - GA_neu, 0)
# Identität: pre + nachschuss + kk_aufnahme - kk_rueckf - ga_anlage + ga_aufl == 0 (Finanzierungssaldo)

# Optionale Sondertilgung aus Überschuss (nur wenn vertraglich zulässig):
st <- pmin(pmax(GA_neu - reserve, 0), B1, sonder_max); GA_neu <- GA_neu - st; B1 <- B1 - st
```

### 5.3 Darlehen mit stochastischem Anschlusszins

Das Ende der Zinsbindung ist eine Eingabe und damit für alle Läufe gleich. Deshalb genügt ein `if` auf t, der neue Zins ist ein Vektor:

```r
if (t > 1 && (t - 1) %% binding1 == 0) {          # neue Konditionen ab Jahr t
  i1 <- pmax(rate[, t - 1] + spread1, i_floor)     # Zinspfad am Ende der Bindung, je Simulation
  A1 <- switch(rule,
    keep_term    = annuity(B1, i1, pmax(n1 - (t - 1), 1)),   # Restlaufzeit beibehalten
    keep_annuity = A1,                                       # Rate beibehalten, Laufzeit variiert
    keep_tilgung = B1 * (i1 + tilg_neu))                     # neuer anfänglicher Tilgungssatz
}
zins1  <- B1 * i1
tilg1  <- pmin(pmax(A1 - zins1, 0), B1)            # keine negative Tilgung, nicht über Restschuld
B1     <- B1 - tilg1
annuity <- function(B, i, n) ifelse(abs(i) < 1e-12, B / n, B * i / (1 - (1 + i)^(-n)))
```

Läuft die Zinsbindung je Simulation unterschiedlich aus, z. B. bei stochastischem Verkaufszeitpunkt oder bei Ausübung des Kündigungsrechts nach § 489 BGB, wird **maskiert** gerechnet:

```r
m <- (t - start >= 10) & (rate[, t - 1] + spread1 < i1 - schwelle)   # Kündigung lohnt sich
i1[m] <- rate[m, t - 1] + spread1
A1[m] <- annuity(B1[m], i1[m], pmax(n1 - (t - 1), 1))
```

Auf dieselbe Weise funktionieren:

- **Ersatzinvestitionen** bei stochastischer Nutzungsdauer: `ers <- -kosten * idx * ((t %% L) == 0)` mit L als Vektor
- **Bauzeitverzug**: Belegungsanteil `occ <- pmin(pmax(t - verzug_monate/12, 0), 1)`
- **Förderzusage**: `tz <- pmin(zuschuss * zusage, B2)`
- **CO₂-Stufenmodell**: `anteil_vermieter <- c(0, .1, .2, .3, .4, .5, .6, .7, .8, .95)[findInterval(kg_m2, c(12, 17, 22, 27, 32, 37, 42, 47, 52)) + 1]`

**Zielwertsuche je Simulation**, etwa die maximale Entnahme nach Grob (Entnahmestreben) oder kritische Werte je Lauf: Eine vektorisierte Bisektion behandelt alle N gleichzeitig mit rund 50 Iterationen; jede Iteration ist ein Engine-Lauf.

```r
vec_bisect <- function(f, lo, hi, iter = 50) {     # f: Vektor -> Vektor, monoton steigend
  for (k in seq_len(iter)) { mid <- (lo + hi) / 2; up <- f(mid) > 0; hi[up] <- mid[up]; lo[!up] <- mid[!up] }
  (lo + hi) / 2
}
```

### 5.4 Vergleich der Strategien und Benchmark

Prototyp: 29 VoFi-Zeilen; Annuitätendarlehen mit 10-jähriger Zinsbindung und zwei stochastischen Resets; KfW-Tilgungsdarlehen mit Tilgungszuschuss bei Förderzusage; Kontokorrent mit Limit; Geldanlage; Miete mit Verzug und Leerstand; Instandhaltung; Verwaltung; CO₂-Vermieteranteil; Ersatzinvestition nach stochastischer Lebensdauer; Restwert mit Exit-Rendite gekoppelt an den Zins in T. Der vollständige Code steht in Anhang A. Umgebung: R 4.3.3, Referenz-BLAS, ein Thread, sofern nicht anders angegeben.

| Variante | N = 10.000, T = 40 | Bemerkung |
|---|---|---|
| **Vektorisierte Engine, nur Kennzahlen** | **0,10 s** | Ergebnisobjekt 0,5 MB |
| Vektorisierte Engine + Fächerbänder (5 Quantile × 3 Größen × 41 Perioden) | 0,15 s | Quantile während der Schleife berechnet |
| Vektorisierte Engine, volle Tabellen (29 Zeilen × N × 41) | 0,20–0,28 s | **91 MiB** |
| Skalierung (nur Kennzahlen) | N = 1.000: 0,01 s · 50.000: 0,50 s · 100.000: 1,1 s | linear |
| T = 80, N = 10.000 (mit Bändern) | 0,26 s | linear in T |
| Engine N-mal mit N = 1 aufrufen (= „deterministische Engine N-mal“) | 3,6–4,7 ms je Lauf → **36–47 s** | Faktor 350–450 langsamer; eine reichere Engine mit `data.frame`/R6 wäre noch langsamer |
| `future.apply`, multisession, 4 Worker (4 Chunks à 2.500) | 0,63–0,87 s | **langsamer** als sequentiell: Kosten für Serialisierung und Transfer der Szenarien (22 MB) |
| Szenarioerzeugung im Prototyp (6 statische Größen inkl. Iman–Conover, 5 Prozesse mit korrelierten Schocks, LHS mit 10 Replikaten, 400.000 Leerstandsziehungen) | 0,49 s (mit direktem `qbeta`: 0,9 s) | Die Ziehung dominiert die Gesamtzeit |
| YAML-Sampler (7 Parameter + 2 unsichere Prozessparameter, 6 Prozesse) | 0,57–0,77 s | Abschnitt 10 |

**Ergebnisgleichheit geprüft:**

- N = 1 vs. vektorisiert: identisch
- parallel vs. sequentiell: identisch
- degenerierte Verteilungen: alle N Läufe gleich dem deterministischen Lauf
- Finanzierungssaldo: max. |Abweichung| 1,9·10⁻⁹ €
- Geldanlage und Kontokorrent: nie gleichzeitig positiv

**Bewertung:**

| Strategie | Vorteile | Nachteile | Empfehlung |
|---|---|---|---|
| A: Skalare deterministische Engine, N-mal aufgerufen | einfachster Code | 36 s bis mehrere Minuten; nicht interaktiv | nein |
| B: wie A, parallelisiert | nutzt Kerne | Overhead, RNG-Verwaltung, auf Shiny-Servern begrenzt; bestenfalls Faktor 3–4 | nein |
| **C: Eine Engine, vektorisiert über N** | 0,1–0,3 s; deterministisch = N = 1; Tornado, Spider, Varianten und Zielwertsuche als Zeilen eines Laufs | erfordert Disziplin (Regeln 5.1) | **ja** |
| D: C + Parallelisierung über Varianten/Chunks | nur bei sehr großen Gittern (Varianten × Sensitivitäten × N) | Overhead | optional ab v2 |
| E: Rcpp/C++ | schneller Kern | Toolchain, Wartung, Prüfbarkeit für Fachanwender | nicht nötig |

### 5.5 Speicherstrategie

| Objekt | Größe | N = 10.000, T = 40 | N = 100.000, T = 80 |
|---|---|---|---|
| Kennzahlen (≈ 10 Spalten) | N · 10 · 8 B | 0,8 MB | 8 MB |
| Szenariopfad je Prozess | N · T · 8 B | 3,2 MB | 64 MB |
| Volle VoFi (29 Zeilen) | 29 · N · (T+1) · 8 B | 95 MB (gemessen 91 MiB) | **1,9 GB** |
| Fächerbänder (5 Quantile, 5 Größen) | 5 · (T+1) · 5 · 8 B | 8 KB | 16 KB |

**Vorgehen:**

- **Kennzahlen speichert das Tool für alle Läufe.** Dazu gehören auch die Pfadmerkmale für die Sensitivitätsanalyse (Abschnitt 7.4) und der Szenarioindex.
- **Fächerbänder entstehen im Streaming:** Je Periode wird `quantile(x, probs)` auf den N-Vektor angewendet und nur die 5–7 Werte gespeichert.
- **Volle Tabellen gibt es nur für ausgewählte Läufe, in einem zweiten Durchgang.** Nach dem Kennzahlenlauf werden die Indizes bestimmt (z. B. die Läufe, die P5/P50/P95 des Endwerts am nächsten liegen). Die Engine rechnet diese Läufe mit `store = "full"` und N = 3 erneut. Das Ergebnis ist identisch, weil die Szenarien gespeichert oder aus dem Seed reproduzierbar sind.
- **Szenarioobjekt** im Speicher halten (22 MB bei N = 10.000). Ab N > 50.000 oder T = 80 mit vielen Prozessen läuft die Rechnung **in Chunks** (z. B. 10.000 Läufe je Chunk, sequentiell): Nur die Kennzahlen werden angehängt. Die Bänder werden über die gespeicherten Kennzahlpfade weniger Größen (1–2 N×T-Matrizen) oder näherungsweise über Histogramme je Periode gebildet.
- Shiny: Die Rechnung läuft im Hintergrund (`ExtendedTask` bzw. `future`/`promises`). Die Vorschau mit N = 1.000 dauert unter 0,2 s.

```r
idx <- vapply(c(0.05, 0.5, 0.95), function(p) which.min(abs(k$endwert - quantile(k$endwert, p))), 1L)
voll <- vofi_engine(subset_scenarios(scen, idx), par, store = "full")   # Tabellen für Bericht/Drilldown
```

---

## 6. Ergebnisgrößen und Risikomaße

### 6.1 Definitionen

| Kennzahl | Definition (je Simulation n) | Hinweise |
|---|---|---|
| **Endwert** $EW^{(n)}_T$ | Bestandssaldo in T: Geldanlage − Kontokorrent − Darlehensbestände, mit Restwert als Zahlung in T | zentrale VoFi-Größe |
| **Opportunität** | $EW^{opp}_T = \sum_t EK_t\prod_{s>t}(1+h^{(n)}_s)$ | **mit demselben Habenzinspfad** h⁽ⁿ⁾ (CRN) |
| **Endwertdifferenz** | $\Delta EW = EW_T - EW^{opp}_T$; für Variantenvergleich $\Delta_{AB} = EW^A_T - EW^B_T$ | Differenz-VoFi |
| **VoFi-Rentabilität** (EK-Rentabilität) | einmaliges EK: $r = (EW_T/EK_0)^{1/T} - 1$; mehrere EK-Zuführungen: $\sum_t EK_t(1+r)^{T-t} = EW_T$ (vektorisiertes Newton-Verfahren) | Undefiniert bei $EW_T \le 0$ oder $EK = 0$ (Vollfinanzierung). **Empfehlung:** r = −100 % setzen und markieren; Anteil ausweisen. Bei EK = 0 nur den Endwert ausweisen |
| P(Verlust ggü. Opportunität) | $\hat p = \frac{1}{N}\sum \mathbb{1}\{\Delta EW < 0\}$, $SE = \sqrt{\hat p(1-\hat p)/N}$ (Pseudo) bzw. aus Replikaten | |
| P(Rentabilität < Hürde) | $\frac{1}{N}\sum \mathbb{1}\{r < r_{H}\}$ | Hürde je Perspektive als Eingabe |
| **VaR**$_\alpha$ (Verlust-Konvention) | $VaR_\alpha = -q_\alpha(\Delta EW)$ | positiv = Verlust. Ist $q_\alpha > 0$, gibt es auf diesem Niveau keinen Verlust. **In der Oberfläche lieber „5-%-Quantil der Endwertdifferenz“ zeigen**, um Vorzeichenverwirrung zu vermeiden |
| **CVaR**$_\alpha$ / Expected Shortfall | $CVaR_\alpha = -E[\Delta EW \mid \Delta EW \le q_\alpha]$ | braucht viele Läufe (Abschnitt 4.4) |
| Erwarteter Verlust | $E[\max(-\Delta EW, 0)]$ | leicht verständlich |
| **P(Liquiditätsengpass)** | $P(\exists t: KK_t > \text{Limit})$ bzw. $P(\exists t: \text{Nachschuss}_t > 0)$ | zusätzlich: Verteilung des Zeitpunkts des ersten Engpasses und des maximalen Nachschusses (P95 = Bedarf an Liquiditätsreserve) |
| **P(DSCR < 1)** | $DSCR_t = NOI_t/\text{Kapitaldienst}_t$; P(min_t DSCR_t < 1) und P(DSCR_t < 1) je Jahr | für Wohnungsunternehmen. Selbstnutzer: **Belastungsquote** (Kapitaldienst / Haushaltsnetto) > Grenze, z. B. 35–40 % |
| P(Beleihungsauslauf > Grenze bei Refinanzierung) | Restschuld / Wert zum Reset-Zeitpunkt | Refinanzierungsrisiko |

Die Zusammenfassung wird auf Deutsch ausgegeben: Mittelwert, Standardabweichung, P5/P25/P50/P75/P95, Basisfall, Anteil undefinierter Renditen und MC-Fehler je Kennzahl.

```r
mc_summary <- function(k, hurdle = 0.04, alpha = 0.05) {
  d <- k$endwert_diff; q <- quantile(d, alpha, names = FALSE); n <- nrow(k)
  p <- function(x) c(p = mean(x), se = sqrt(mean(x) * (1 - mean(x)) / n))
  r <- ifelse(is.na(k$vofi_rendite), -1, k$vofi_rendite)          # EW <= 0 -> -100 %
  list(endwert = c(mean = mean(k$endwert), sd = sd(k$endwert),
                   quantile(k$endwert, c(.05, .25, .5, .75, .95))),
       p_verlust = p(d < 0), p_rendite_unter_huerde = p(r < hurdle),
       quantil_diff = q, cvar = -mean(d[d <= q]), erwarteter_verlust = mean(pmax(-d, 0)),
       p_liquiditaet = p(k$liquiditaetsengpass), p_dscr_unter_1 = p(k$min_dscr < 1),
       anteil_rendite_undefiniert = mean(is.na(k$vofi_rendite)))
}
vofi_rendite <- function(EK, EW, iter = 30, r0 = 0.05) {   # EK: N x (T+1), Spalte 1 = t0; Newton vektorisiert
  T <- ncol(EK) - 1; e <- T - (0:T); r <- rep(r0, nrow(EK)); ok <- EW > 0 & rowSums(EK) > 0
  for (k in seq_len(iter)) {
    q <- outer(1 + r, e, "^"); f <- rowSums(EK * q) - EW
    df <- rowSums(EK * sweep(q, 2, e, "*") / (1 + r)); r <- pmax(r - f / df, -0.99)
  }
  ifelse(ok, r, NA_real_)
}
```

### 6.2 Grafiken (ggplot2, deutsch beschriftet)

1. **Fächerdiagramm** je Jahr (5/25/50/75/95 %) für Bestandssaldo, Nettoliquidität (Anlage − Kontokorrent), DSCR bzw. Belastungsquote und wichtige Eingangspfade (Zins, CO₂, Energiepreis), mit Basisfall als Linie.
2. **Histogramm und ECDF** von Endwert, Endwertdifferenz und Rentabilität, mit Markierungen für Basisfall, Mittelwert, P5/P95, null bzw. Hürde. Mehrere Varianten als ECDF in einem Diagramm.
3. **Tornado**, **Spider**, **Konvergenzplot**.
4. **Bedingte Auswertungen**: Facetten nach CO₂-Szenario oder nach Förderzusage (Szenarioindex wird gespeichert).
5. **Mittelwert–CVaR-Diagramm** für Varianten (Effizienzsicht).

### 6.3 Vergleich von Alternativen

- **P(A schlägt B)** $= \frac{1}{N}\sum \mathbb{1}\{EW^A_n > EW^B_n\}$, **nur mit CRN sinnvoll** (Abschnitt 8). Ausgewiesen werden außerdem die Verteilung von $\Delta_{AB}$ (Histogramm, Quantile) und das „Bedauern“ $E[\max(EW^B - EW^A, 0)]$.
- **Stochastische Dominanz 1. Ordnung**: $F_A(x) \le F_B(x)$ für alle x. **2. Ordnung**: $\int_{-\infty}^x F_A \le \int_{-\infty}^x F_B$ für alle x. Geprüft wird auf einem Gitter aus 500 gemeinsamen Quantilen, ausgegeben wird „gegeben / nicht gegeben, maximale Verletzung“. Dominanz liegt selten vor (im Prototyp nicht), und P(A > B) sowie die Δ-Verteilung sind aussagekräftiger.

```r
dominance <- function(a, b, m = 500) {
  grid <- quantile(c(a, b), seq(0.001, 0.999, length.out = m), names = FALSE)
  FA <- ecdf(a)(grid); FB <- ecdf(b)(grid); dx <- c(0, diff(grid))
  list(fsd = all(FA <= FB + 1e-12), max_verletzung_fsd = max(FA - FB),
       ssd = all(cumsum(FA * dx) <= cumsum(FB * dx) + 1e-9))
}
```

---

## 7. Sensitivitätsanalyse

### 7.1 Deterministischer Tornado (One-at-a-time) und Spider-Plot in einem Lauf

Aus dem Basisfall (N = 1) baut das Tool ein Szenarioobjekt mit $1 + 2k$ Zeilen: Zeile 1 ist der Basisfall, danach folgt je Parameter eine Zeile mit dem unteren und eine mit dem oberen Wert. Der Default sind P10/P90 der hinterlegten Verteilung, alternativ min/max oder ±x %. **Ein einziger Engine-Aufruf rechnet alle Varianten**; im Prototyp dauerten 11 Zeilen 0,004–0,007 s. Der Spider-Plot funktioniert analog mit $k \times m$ Zeilen (z. B. −20 % … +20 % in 9 Stufen).

Für Prozesse werden **Treiberparameter** variiert (μ, θ, Trendwachstum, Szenariowahl), keine punktweisen Pfadquantile. Ein Pfad aus lauter P90-Werten ist kein realistischer Pfad.

```r
tornado_scenarios <- function(base, lo_hi) {        # base: Szenarioobjekt mit N = 1
  nr <- 1 + 2 * length(lo_hi)
  s <- lapply(base, function(x) if (is.matrix(x)) x[rep(1, nr), , drop = FALSE] else rep(x, nr))
  i <- 2
  for (nm in names(lo_hi)) { s[[nm]][i] <- lo_hi[[nm]][1]; s[[nm]][i + 1] <- lo_hi[[nm]][2]; i <- i + 2 }
  s
}
# k <- vofi_engine(tornado_scenarios(base, list(cost_factor = c(0.98, 1.22), ...)), par)$kpi
# Wirkung = k$endwert_diff[-1] - k$endwert_diff[1], paarweise (tief, hoch), sortiert nach Spannweite
```

Ergebnis im Prototyp (Endwertdifferenz, Abweichung vom Basisfall): Baukostenfaktor 0,98/1,22 → +0,13 Mio. / −2,20 Mio. €; Exit-Schock ±0,5 Pp. → +1,19 / −0,91 Mio. €; Nutzungsdauer WP 14/22 J. → +0,02 / +0,31 Mio. €. Der Effekt ist nicht monoton, weil bei 22 Jahren nur noch ein Ersatz in 40 Jahren anfällt: ein Treppeneffekt (siehe 7.3).

### 7.2 Kritische Werte (Break-even) mit `uniroot`

Gesucht ist der Wert $x^*$ eines Parameters, bei dem die Kennzahl die Schwelle erreicht (z. B. ΔEW = 0 oder r = Hürde), alle anderen Parameter auf dem Basisfall. Im Prototyp lag der kritische Baukostenfaktor bei 1,450 (8 Iterationen, 0,04 s). Das Tool prüft dabei:

- vorab das Vorzeichen an den Intervallgrenzen; sonst Ausgabe „kein kritischer Wert im Intervall“
- danach $|f(x^*)|$; ist der Wert groß, liegt eine **Sprungstelle** statt einer Nullstelle vor

Die MC-Verbindung liefert eine anschauliche Zusatzinformation: $P(X > x^*)$ unter der hinterlegten Verteilung, ceteris paribus, also die „Wahrscheinlichkeit, die Wirtschaftlichkeitsschwelle zu überschreiten“.

```r
break_even <- function(param, interval, kpi = "endwert_diff", target = 0, base, par) {
  f <- function(x) { s <- base; s[[param]] <- x; vofi_engine(s, par)$kpi[[kpi]] - target }
  fl <- f(interval[1]); fu <- f(interval[2])
  if (sign(fl) == sign(fu)) return(list(root = NA, meldung = "Kein kritischer Wert im Intervall"))
  ur <- uniroot(f, interval, f.lower = fl, f.upper = fu, tol = 1e-8)
  list(root = ur$root, iter = ur$iter, sprungstelle = abs(f(ur$root)) > 1)   # Toleranz in EUR
}
```

### 7.3 Sprungstellen und Diskontinuitäten

Ganzzahlige Nutzungsdauern, Bernoulli-Größen (Förderzusage) und Stufenmodelle (CO2KostAufG, Kappungsgrenzen) machen die Zielfunktion stückweise konstant. Folgen: Bei `uniroot` landet man auf Sprüngen, OAT-Ergebnisse sind nicht monoton, und regressionsbasierte Maße verlieren an Aussagekraft. Gegenmaßnahmen:

- **Anteiliger Restwert** des zuletzt ersetzten Bauteils in T (linear über die Nutzungsdauer). Das ist ohnehin VoFi-konform und glättet Lebensdauereffekte.
- Diskrete Größen in der Sensitivität als **Gruppen** behandeln (bedingte Mittelwerte statt Regression).

### 7.4 Globale Sensitivität aus der MC-Stichprobe

Eingaben sind die statischen Parameter sowie **Pfadmerkmale** der Prozesse:

- Mittelwert des Zinses über den Horizont, Zins am Reset und in T
- mittlere Inflation, mittleres Mietwachstum
- CO₂-Szenarioindex, mittlerer Leerstand

Diese Merkmale berechnet das Tool beim Sampling und speichert sie mit.

| Maß | Berechnung | Aussage | Base R |
|---|---|---|---|
| **Spearman** $\rho_S(X_j, Y)$ | `cor(x, y, method = "spearman")` | monotoner Gesamtzusammenhang inkl. Korrelationen mit anderen Eingaben | ja |
| **SRC** (standardisierte Regressionskoeffizienten) | `lm(scale(y) ~ scale(X))` | linearer Partialeffekt. Bei unabhängigen Eingaben gilt $\sum SRC^2 \approx R^2$; nur bei $R^2 \gtrsim 0{,}7$ interpretieren | ja |
| **SRRC** | SRC auf Rängen | robust gegen Nichtlinearität, wenn der Zusammenhang monoton ist | ja |
| **PRCC** | Ränge; Residuen von rank(X_j) und rank(Y) nach Regression auf alle anderen Ränge; deren Korrelation | partieller monotoner Effekt, „bereinigt“ um andere Eingaben (Marino et al. 2008) | ja, `lm.fit` |
| **Haupteffekt-Index über Klassen** (binned S1) | $S_j \approx Var(E[Y \mid \text{Klasse}(X_j)])/Var(Y)$ mit 20–50 gleich besetzten Klassen | varianzbasierter Haupteffekt ohne spezielles Design, auch für diskrete Größen | ja |
| Sobol (erster Ordnung, total) | Saltelli-Design, k + 2 Matrizen | Wechselwirkungen | v2 |

```r
src <- function(X, y) {
  f <- lm(as.vector(scale(y)) ~ scale(X))
  list(coef = setNames(coef(f)[-1], colnames(X)), r2 = summary(f)$r.squared)
}
prcc <- function(X, y) {
  R <- apply(X, 2, rank); ry <- rank(y)
  setNames(vapply(seq_len(ncol(R)), function(j) {
    Z <- cbind(1, R[, -j]); cor(lm.fit(Z, R[, j])$residuals, lm.fit(Z, ry)$residuals)
  }, numeric(1)), colnames(X))
}
first_order_binned <- function(x, y, bins = 30) {
  g <- if (length(unique(x)) <= bins) factor(x) else cut(rank(x, ties.method = "first"), bins, labels = FALSE)
  m <- tapply(y, g, mean); w <- tabulate(as.integer(factor(g))) / length(y)
  sum(w * (m - mean(y))^2) / var(y)
}
```

### 7.5 Ergebnis im Prototyp

N = 10.000 mit LHS; Zielgröße Endwertdifferenz; Laufzeit PRCC für 12 Größen 0,09 s.

| Eingabe | Spearman | SRC | PRCC | SRRC | binned S1 |
|---|---|---|---|---|---|
| Baukostenfaktor | −0,42 | −0,47 | −0,57 | −0,40 | 0,30 |
| Mietwachstum (Mittel) | +0,51 | +0,96 | +0,62 | +0,98 | 0,22 |
| Inflation (Mittel) | **+0,40** | **−0,40** | −0,29 | −0,38 | 0,13 |
| Zins in T (Exit) | −0,32 | −0,42 | −0,66 | −0,44 | 0,12 |
| Bauzeitverzug | −0,25 | −0,05 | −0,09 | −0,05 | 0,08 |
| Exit-Schock | −0,24 | −0,22 | −0,44 | −0,24 | 0,05 |
| Anschlusszins Jahr 10 | −0,12 | −0,24 | −0,40 | −0,22 | 0,02 |
| Performance Gap, Förderung, CO₂-Szenario, Leerstand | < 0,04 | < 0,04 | < 0,08 | < 0,03 | < 0,01 |

R² (SRC) = 0,76; Summe der S1 = 0,94.

**Interpretationshinweise für die Oberfläche:**

1. **Vorzeichenwechsel bei korrelierten Eingaben.** Die Inflation hat einen positiven Gesamteffekt, weil die Miete an sie gekoppelt ist. Der partielle Effekt bei gegebener Miete ist negativ (Kosten). Spearman und SRC beantworten verschiedene Fragen.
2. PRCC übertreibt kleine Effekte, wenn die übrigen Eingaben viel Varianz erklären. Für die **Rangfolge der Varianzbeiträge** sind S1 oder SRC² besser.
3. Im Prototyp ist die CO₂-Wirkung gering, weil der Vermieteranteil nach Sanierung klein ist. Beim Selbstnutzer oder im unsanierten Vergleichsfall ist das anders. Die Rangfolge ist also projektspezifisch, und Defaults dürfen keine Wichtigkeit suggerieren.

---

## 8. Common Random Numbers (gemeinsame Zufallszahlen)

### 8.1 Warum CRN unverzichtbar ist

Für die Differenz zweier Varianten gilt $Var(\bar\Delta) = \frac{1}{N}\big(Var(EW^A) + Var(EW^B) - 2\,Cov(EW^A, EW^B)\big)$. Werden beide Varianten mit **denselben** Umweltpfaden gerechnet (Zinsen, Energie, CO₂, Inflation, Miete), ist die Kovarianz groß und die Differenz präzise. Noch wichtiger ist die inhaltliche Seite: **Nur mit CRN beantwortet „P(A schlägt B)“ die Frage „In wie vielen möglichen Zukünften ist A besser?“** Ohne CRN misst die Kennzahl, mit welcher Wahrscheinlichkeit ein zufälliges A-Ergebnis ein unabhängig gezogenes B-Ergebnis übertrifft. Das ist für Entscheidungen bedeutungslos.

**Prototyp** (Variante A: Effizienzhaus mit WP und Förderung; Variante B: günstigere Ausführung ohne Einsparung; N = 10.000; die Zahlen sind keine inhaltliche Aussage):

| | mit CRN | unabhängige Ziehungen |
|---|---|---|
| Mittlere Endwertdifferenz A − B | −462.633 € | −467.233 € |
| Standardfehler | **4.943 €** | 43.931 € |
| Varianzreduktion | **Faktor 79** | – |
| P(A schlägt B) | **4,9 %** (SE 0,2 Pp.) | 45,9 % (inhaltlich falsch) |
| Korrelation EW^A, EW^B | 0,99 | ≈ 0 |

### 8.2 Umsetzung

1. **Ein Szenarioobjekt je Analyse.** Es wird einmal aus der Vereinigung aller stochastischen Größen aller Varianten erzeugt, und alle Varianten werden darauf gerechnet. Die Opportunität nutzt denselben Habenzinspfad.
2. **Benannte Ströme** (Abschnitt 4.3) sorgen dafür, dass eine variantenspezifische Größe (z. B. die Kostenüberschreitung einer Maßnahme, die nur B hat) die Ziehungen der anderen nicht verschiebt.
3. **Gleiche Bedeutung = gleicher Name.** Teilen beide Varianten dasselbe Risiko (dieselbe Zinsentwicklung, derselbe Prebound-Faktor des Haushalts), verwenden sie denselben Eintrag. Sind die Risiken verschieden, aber verwandt (Baukostenrisiko zweier Ausführungen), bekommen sie getrennte Namen und eine Rangkorrelation (z. B. 0,7).
4. **Differenzen werden je Simulation gebildet.** Es werden nie Verteilungen oder Quantile voneinander abgezogen: $q_p(EW^A) - q_p(EW^B) \ne q_p(EW^A - EW^B)$.
5. **Kalenderjahr-Indexierung** der Pfade, damit Varianten mit anderem Projektbeginn konsistent bleiben.
6. Optional werden Szenarioobjekte als RDS gespeichert („Szenariobibliothek“), damit sich Analysen über Sitzungen hinweg identisch wiederholen lassen.

Test: Zwei identische Varianten müssen in jeder Simulation die Differenz **exakt 0** ergeben (Abschnitt 9).

---

## 9. Validierung des MC-Moduls

| Test | Kriterium | Umsetzung |
|---|---|---|
| Momente der Verteilungen | \|Mittelwert − Soll\| < 4 SE; sd ± 3 %; KS-Test p > 10⁻³ (fester Seed) | je Verteilungstyp, N = 20.000 |
| Parametrisierungen | Lognormal: Median/P90 bzw. Mittelwert/sd getroffen; PERT- und Dreiecksmittel exakt | Formeln aus 2.1 |
| LHS-Schichtung | `sort(floor(u * N)) == 0:(N-1)` je Spalte und je Replikat | |
| Korrelation reproduziert | max \|ρ_S − Ziel\| < 0,02 (N = 20.000); **Randverteilungen nach Iman–Conover identisch** | |
| nearPD | Eigenwerte > 0, Diagonale 1, `chol()` läuft | |
| Prozesse | Vasicek: E[r_t] = θ + (r₀ − θ)e^{−κt}; AR(1): stationäre sd und Lag-1-Autokorrelation; GBM: E[P_T] = P₀(1+g)^T; Floor eingehalten; `mr_trend`: E[P_t] = Trend_t; Bootstrap: Mittel = Recenter-Ziel | |
| Seeds | gleicher Seed → identisch; anderer Seed → verschieden; **globaler RNG-Zustand unverändert**; Zusatzparameter ändert andere Ziehungen nicht; Ergebnis unabhängig von der Worker-Zahl | |
| Degeneriert | alle Verteilungen `fixed` bzw. σ = 0 → alle N Läufe identisch **und gleich dem deterministischen Lauf** (Toleranz 10⁻¹⁰) | Kernabnahme „deterministisch = Spezialfall“ |
| VoFi-Invarianten | Finanzierungssaldo = 0 in jeder Periode und Simulation; nie Anlage und Kontokorrent gleichzeitig; Darlehensbestand ≥ 0 | |
| N = 1 vs. vektorisiert | Ergebnisse der Zeilen i identisch | fängt verbotene `if`-Logik ab |
| CRN | identische Varianten → Differenz exakt 0 | |
| Antithetik | lineare Funktion → Paarmittel exakt gleich dem Erwartungswert | |
| Regression | Referenzbeispiel aus der Literatur (Grob) deterministisch; MC-Snapshot (Seed fix) mit Kennzahl-Toleranzen | `testthat::expect_snapshot_value` |
| Spezifikation | Validierung mit `checkmate`: min ≤ mode ≤ max; Summe probs = 1; p ∈ [0, 1]; sd > 0; `target` existiert; Korrelationen in [−1, 1]; Prozessparameter zulässig (κ > 0, \|φ\| < 1) | Fehlermeldungen auf Deutsch |

Testdatei aus dem Prototyp (26 Erwartungen, alle bestanden):

```r
library(testthat)
seed <- 4711; N <- 20000

test_that("Momente der Verteilungen liegen im Toleranzband (4 SE)", {
  u <- draw_u(N, seed, "t1", "pseudo")
  x <- q_pert(u, 0.95, 1.05, 1.40)
  m_th <- (0.95 + 4 * 1.05 + 1.40) / 6
  a <- 1 + 4 * (1.05 - 0.95) / 0.45; b <- 1 + 4 * (1.40 - 1.05) / 0.45
  sd_th <- 0.45 * sqrt(a * b / ((a + b)^2 * (a + b + 1)))
  expect_lt(abs(mean(x) - m_th), 4 * sd_th / sqrt(N))
  expect_lt(abs(sd(x) / sd_th - 1), 0.03)
  x <- q_triangular(u, 0, 3, 12)
  expect_lt(abs(mean(x) - 5), 4 * sqrt((0 + 9 + 144 - 0 - 0 - 36) / 18) / sqrt(N))
  p <- lnorm_par(mean = 1.1, sd = 0.1); x <- qlnorm(u, p[1], p[2])
  expect_lt(abs(mean(x) - 1.1), 4 * 0.1 / sqrt(N))
  expect_gt(ks.test(q_truncnorm(u, 0, 1, -1, 2),
                    function(q) (pnorm(q) - pnorm(-1)) / (pnorm(2) - pnorm(-1)))$p.value, 1e-3)
})

test_that("LHS ist je Spalte exakt stratifiziert", {
  u <- draw_u(1000, seed, "lhs", "lhs")
  expect_equal(sort(floor(u * 1000)), 0:999)
})

test_that("Rangkorrelation wird reproduziert, Ränder bleiben erhalten (Iman-Conover)", {
  R <- matrix(c(1, .5, -.3, .5, 1, .2, -.3, .2, 1), 3)
  X <- cbind(q_pert(draw_u(N, seed, "a", "lhs"), 0, 1, 5), qexp(draw_u(N, seed, "b", "lhs")),
             draw_u(N, seed, "c", "lhs"))
  Y <- iman_conover(X, R, seed)
  expect_lt(max(abs(cor(Y, method = "spearman") - R)), 0.02)
  for (j in 1:3) expect_identical(sort(Y[, j]), sort(X[, j]))
})

test_that("Nearest-PD liefert gültige Korrelationsmatrix", {
  R2 <- near_pd_corr(matrix(c(1, .9, -.6, .9, 1, .2, -.6, .2, 1), 3))
  expect_true(all(eigen(R2, symmetric = TRUE)$values > 0)); expect_equal(diag(R2), rep(1, 3))
  expect_silent(chol(R2))
})

test_that("Seeds: reproduzierbar, globaler RNG unberührt", {
  expect_identical(draw_u(10, seed, "x"), draw_u(10, seed, "x"))
  expect_false(identical(draw_u(10, seed, "x"), draw_u(10, seed + 1, "x")))
  set.seed(1); a <- runif(1); set.seed(1); invisible(draw_u(5, seed, "y")); expect_identical(runif(1), a)
})

test_that("Prozesse: Vasicek-Erwartung, AR(1)-Stationarität, Floor, GBM", {
  Z <- draw_shocks(N, 30, seed, "r")
  r <- sim_vasicek(Z, 0.05, 0.03, 0.2, 0.005)
  expect_lt(abs(mean(r[, 5]) - (0.03 + 0.02 * exp(-1))), 4 * sd(r[, 5]) / sqrt(N))
  expect_true(all(sim_vasicek(Z, 0.01, 0.01, 0.1, 0.02, floor = 0) >= 0))
  g <- sim_ar1(Z, 0.02, 0.6, 0.01)
  expect_lt(abs(sd(g[, 30]) / (0.01 / sqrt(1 - 0.36)) - 1), 0.03)
  expect_lt(abs(cor(g[, 29], g[, 30]) - 0.6), 0.03)
  P <- sim_gbm(Z, 1, 0.02, 0.1)
  expect_lt(abs(mean(P[, 30]) / 1.02^30 - 1), 4 * sd(P[, 30]) / sqrt(N) / 1.02^30)
})

test_that("Degenerierte Verteilungen => Ergebnis = deterministische Rechnung (N = 1)", {
  scd <- gen_scenarios(50, 40, seed, degenerate = TRUE)
  k  <- vofi_engine(scd, par_default)$kpi
  k1 <- vofi_engine(lapply(scd, function(x) if (is.matrix(x)) x[1, , drop = FALSE] else x[1]), par_default)$kpi
  expect_true(all(vapply(k, function(v) length(unique(v)) == 1, logical(1))))
  expect_equal(k[1, ], k1, ignore_attr = TRUE, tolerance = 1e-10)
})

test_that("VoFi-Invarianten: Finanzierungssaldo 0, nie Anlage und Kontokorrent zugleich", {
  f <- vofi_engine(gen_scenarios(500, 40, seed, "lhs"), par_default, "full")$full
  expect_lt(max(abs(f$finanzierungssaldo)), 1e-6)
  expect_false(any(f$bestand_ga > 0 & f$bestand_kk > 0))
})

test_that("CRN: identische Varianten haben Differenz exakt 0", {
  sc <- gen_scenarios(500, 40, seed, "lhs")
  expect_identical(vofi_engine(sc, par_default)$kpi$endwert - vofi_engine(sc, par_default)$kpi$endwert,
                   rep(0, 500))
})
```

---

## 10. Spezifikationsformat (YAML) und Sampler

### 10.1 Konzept

- **Overlay statt Inline:** Die deterministische Projektdatei bleibt unverändert und ist der Basisfall. Eine separate Stochastik-Datei bzw. ein Abschnitt `stochastic` überschreibt per `target` (Pfad in der Projekteingabe) einzelne Größen durch Verteilungen oder Prozesse. Vorteile:
  - Stochastik lässt sich ein- und ausschalten.
  - Für ein Projekt kann es mehrere Stochastik-Profile geben (vorsichtig/neutral).
  - Der Basiswert für Tornado und deterministische Rechnung ist eindeutig.
- Schlüssel englisch (snake_case), `label` und Kommentare deutsch. **Prozentangaben als Dezimalzahl** (0.02 = 2 %).
- **Datei-Encoding UTF-8.** Im Container (Locale `C`/`POSIX`) bricht `yaml::read_yaml()` an Umlauten ab („invalid input found on input connection“). Robust ist `yaml::yaml.load(paste(readLines(path, encoding = "UTF-8"), collapse = "\n"))`.
- Ist `mode` eines PERT ungleich dem deterministischen Basiswert, gibt die Validierung einen Hinweis aus (kein Fehler). Basiswerte außerhalb [min, max] sind ein Fehler.

### 10.2 Beispielspezifikation (im Prototyp getestet)

```yaml
# Stochastische Spezifikation – Overlay auf die deterministischen Projekteingaben.
# Schlüssel englisch (snake_case), Beschriftungen (label) deutsch.
stochastic:
  settings:
    n_sim: 10000
    seed: 20261025
    sampling: lhs              # pseudo | lhs
    replicates: 10             # replizierte LHS (ehrliche Standardfehler)
    antithetic: false          # nur mit sampling: pseudo sinnvoll
    copula: iman_conover       # iman_conover | gaussian
    start_year: 2026           # t = 0
    horizon: 40                # Jahre (sonst aus Projekt)
    store: bands               # kpi | bands | full
    keep_runs: [p05, p50, p95] # vollständige VoFi-Tabellen nur für diese Läufe

  parameters:                  # statisch: genau eine Ziehung je Simulation
    construction_cost_factor:
      target: construction.cost_factor
      label: "Baukostenabweichung (Faktor auf Kostenschätzung)"
      dist: pert
      min: 0.95
      mode: 1.05
      max: 1.40
    construction_delay_months:
      target: construction.delay_months
      label: "Bauzeitverzug (Monate)"
      dist: pert
      min: 0
      mode: 2
      max: 12
    subsidy_approved:
      target: funding.grant.approved
      label: "Förderzusage erteilt"
      dist: bernoulli
      p: 0.85
    savings_realisation:
      target: energy.savings_realisation
      label: "Realisierungsgrad der berechneten Einsparung"
      dist: pert
      min: 0.40
      mode: 0.80
      max: 1.05
    heat_pump_lifetime:
      target: components.heat_pump.lifetime
      label: "Nutzungsdauer Wärmepumpe (Jahre)"
      dist: triangular
      min: 12
      mode: 18
      max: 25
    exit_yield_shock:
      target: exit.yield_shock
      label: "Abweichung Exit-Rendite (absolut)"
      dist: normal
      mean: 0
      sd: 0.004
    vacancy_level:
      target: revenue.vacancy_rate
      label: "Leerstandsquote (Niveau)"
      dist: lognormal          # Hinweis: unbeschränkt; für Quoten besser pert/truncnorm
      median: 0.02
      p90: 0.05

  processes:                   # Zeitreihen: genau ein Pfad je Simulation
    inflation:
      target: market.inflation
      label: "Inflationsrate VPI"
      type: ar1
      mu: {dist: normal, mean: 0.02, sd: 0.004}   # Parameterunsicherheit (Trend)
      phi: 0.5
      sigma: 0.011
      x0: 0.022
    mortgage_rate:
      target: financing.follow_up_rate
      label: "Bauzins 10 J. Zinsbindung (Anschlussfinanzierung)"
      type: vasicek              # Defaults kalibriert an Bundesbank SUD119 (Abschnitt 2.3)
      r0: 0.040
      theta: 0.0375
      kappa: 0.12
      sigma: 0.007
      floor: 0.005
    rent_growth:
      target: revenue.rent_growth
      label: "Mietsteigerung p.a."
      type: linked_ar1           # g_t = a + b * basis_t + AR(1)-Abweichung
      base: inflation
      a: 0.002
      b: 0.8
      phi: 0.5
      sigma: 0.006
    co2_price:
      target: energy.co2_price
      label: "CO2-Preis BEHG/ETS2 (EUR/t)"
      type: scenario_mix
      scenarios:
        niedrig: {prob: 0.3, years: [2026, 2030, 2045, 2066], values: [60, 70, 90, 100]}
        mittel:  {prob: 0.5, years: [2026, 2030, 2045, 2066], values: [60, 120, 200, 250]}
        hoch:    {prob: 0.2, years: [2026, 2030, 2045, 2066], values: [60, 200, 300, 350]}
      noise: {phi: 0.8, sigma: 0.15}
    gas_price:
      target: energy.price.gas
      label: "Gaspreis Haushalte ohne CO2-Anteil (EUR/kWh)"
      type: mr_trend               # ln P_t = ln Trend_t + AR(1)-Abweichung
      p0: 0.10
      growth: {dist: normal, mean: 0.02, sd: 0.01}   # Trendunsicherheit
      phi: 0.75
      sigma: 0.08
    vacancy_fluctuation:
      target: revenue.vacancy_fluctuation
      label: "Jährliche Leerstandsschwankung (Faktor)"
      type: iid
      dist_spec: {dist: pert, min: 0.5, mode: 1.0, max: 2.0}

  correlations:
    parameters:                # Rangkorrelation (Spearman) statischer Parameter
      - [construction_cost_factor, construction_delay_months, 0.5]
    shocks:                    # Korrelation der jährlichen Schocks
      - [inflation, mortgage_rate, 0.4]
      - [inflation, rent_growth, 0.3]
      - [inflation, gas_price, 0.6]
```

Hinweise zu Erweiterungen der Syntax:

- Rangkorrelationen von Prozessparametern verweisen auf `prozess.param`, z. B. `[inflation.mu, mortgage_rate.theta, 0.5]`.
- Stresstests als `type: fixed_path` mit `years`/`values`.
- Bootstrap als `type: bootstrap` mit `data_file`, `block`, `recenter` und `group` (Reihen derselben Gruppe werden gemeinsam gezogen).
- `bounds: [lower, upper]` je Prozess für Plausibilitätsgrenzen.

### 10.3 Sampler (Prototyp, getestet)

Ergebnisse des Tests:

- Spezifikation aus 10.2 mit N = 10.000: 0,57–0,77 s
- Rangkorrelation Kosten/Verzug 0,500
- identisches Ergebnis bei erneutem Lauf
- Zusatzparameter ändert die übrigen Ziehungen und Pfade nicht
- `fixed` → konstant
- E[Gaspreis₄₀] = 0,238 (theoretisch 0,10 · E[(1+g)⁴⁰] = 0,238)

```r
read_stochastic_spec <- function(path) {            # locale-unabhängig (auch unter LC_ALL=C)
  txt <- readLines(path, encoding = "UTF-8", warn = FALSE)
  yaml::yaml.load(paste(txt, collapse = "\n"))$stochastic
}
corr_from_pairs <- function(pairs, names) {
  R <- diag(length(names)); dimnames(R) <- list(names, names)
  for (p in pairs) R[p[[1]], p[[2]]] <- R[p[[2]], p[[1]]] <- as.numeric(p[[3]])
  R
}
is_dist <- function(x) is.list(x) && !is.null(x$dist)

sample_stochastic <- function(spec, n = NULL) {
  st <- spec$settings; n <- n %||% st$n_sim; T <- st$horizon; seed <- st$seed
  meth <- st$sampling %||% "pseudo"; anti <- isTRUE(st$antithetic)
  rep  <- if (meth == "lhs") as.integer(st$replicates %||% 1L) else 1L
  years <- st$start_year + seq_len(T)
  U_of <- function(name) draw_u(n, seed, name, meth, anti, rep)

  # 1) statische Parameter + unsichere Prozessparameter ("prozess.param")
  pars <- spec$parameters
  for (pn in names(spec$processes)) for (k in setdiff(names(spec$processes[[pn]]), "dist_spec"))
    if (is_dist(spec$processes[[pn]][[k]])) pars[[paste(pn, k, sep = ".")]] <- spec$processes[[pn]][[k]]
  U <- matrix(vapply(names(pars), function(nm) U_of(paste0("par:", nm)), numeric(n)),
              n, dimnames = list(NULL, names(pars)))
  cp  <- spec$correlations$parameters
  grp <- unique(unlist(lapply(cp, function(p) unlist(p[1:2]))))
  cop <- st$copula %||% "iman_conover"
  if (length(grp) && cop == "gaussian")
    U[, grp] <- gauss_copula(U[, grp, drop = FALSE], corr_from_pairs(cp, grp))
  X <- U
  for (nm in names(pars)) X[, nm] <- quantile_fun(pars[[nm]])(U[, nm])
  if (length(grp) && cop == "iman_conover")
    X[, grp] <- iman_conover(X[, grp, drop = FALSE], corr_from_pairs(cp, grp), seed, "ic:parameters", rep)
  getp <- function(p, k) { v <- spec$processes[[p]][[k]]; if (is_dist(v)) X[, paste(p, k, sep = ".")] else v }

  # 2) Schocks je Prozess (benannte Ströme) + Kreuzkorrelation
  pn <- names(spec$processes)
  Z <- lapply(setNames(pn, pn), function(p) draw_shocks(n, T, seed, p, meth, anti, rep))
  if (length(spec$correlations$shocks)) Z <- correlate_shocks(Z, corr_from_pairs(spec$correlations$shocks, pn))

  # 3) Pfade (verknüpfte Prozesse nach ihren Basisprozessen)
  paths <- list()
  for (p in pn[order(vapply(spec$processes, function(s) !is.null(s$base), logical(1)))]) {
    s <- spec$processes[[p]]
    paths[[p]] <- switch(s$type,
      fixed_path   = matrix(approx(unlist(s$years), unlist(s$values), xout = years, rule = 2)$y, 1, T),
      iid          = sim_iid(pnorm(Z[[p]]), tabulate_qf(quantile_fun(s$dist_spec))),
      ar1          = sim_ar1(Z[[p]], getp(p, "mu"), getp(p, "phi"), getp(p, "sigma"), s$x0 %||% getp(p, "mu")),
      vasicek      = sim_vasicek(Z[[p]], s$r0, getp(p, "theta"), getp(p, "kappa"), getp(p, "sigma"),
                                 s$floor %||% -Inf),
      gbm          = sim_gbm(Z[[p]], s$p0, getp(p, "growth"), getp(p, "sigma")),
      mr_trend     = sim_mr_trend(Z[[p]], s$p0 * outer(rep_len(1 + getp(p, "growth"), n), seq_len(T), "^"),
                                  getp(p, "phi"), getp(p, "sigma")),
      linked_ar1   = getp(p, "a") + getp(p, "b") * paths[[s$base]] +
                     sim_ar1(Z[[p]], 0, getp(p, "phi"), getp(p, "sigma"), 0),
      scenario_mix = {
        sc <- s$scenarios
        P  <- t(vapply(sc, function(x) approx(unlist(x$years), unlist(x$values), xout = years, rule = 2)$y,
                       numeric(T)))
        sim_scenario_mix(U_of(paste0("scen:", p)), P, vapply(sc, `[[`, numeric(1), "prob"),
                         Z[[p]], s$noise$sigma %||% 0, s$noise$phi %||% 0)
      },
      stop("Unbekannter Prozesstyp: ", s$type))
  }
  structure(list(parameters = as.data.frame(X), paths = paths, years = years,
                 meta = list(seed = seed, n = n, sampling = meth, replicates = rep,
                             rng = "Mersenne-Twister/Inversion/Rejection, benannte Ströme",
                             r_version = R.version.string, created = Sys.time())),
            class = "vofi_scenarios")
}
```

Anschließend bindet `apply_scenarios(project, scen)` jedes `target` an die Engine-Eingaben: Statische Parameter werden zu Vektoren der Länge N, Prozesse zu N×T-Matrizen, deterministische Pfade zu 1×T-Matrizen. Das Szenarioobjekt bleibt unabhängig vom Projekt und lässt sich deshalb für mehrere Varianten wiederverwenden (CRN).

---

## 11. Modulschnitt und Umsetzungsplan

| Datei (R/) | Inhalt | Wichtige Funktionen |
|---|---|---|
| `mc_rng.R` | benannte Ströme, LHS, Antithetik | `with_stream`, `draw_u`, `draw_shocks`, `lhs_vector` |
| `mc_distributions.R` | Quantilfunktionen, Tabellierung, PERT aus Quantilen | `quantile_fun`, `tabulate_qf`, `pert_from_quantiles` |
| `mc_dependence.R` | Korrelationsmatrizen, nearPD, Copula, Iman–Conover | `corr_from_pairs`, `near_pd_corr`, `gauss_copula`, `iman_conover`, `correlate_shocks` |
| `mc_processes.R` | Prozesse und Kalibrierung | `sim_ar1`, `sim_vasicek`, `sim_mr_trend`, `sim_gbm`, `sim_scenario_mix`, `sim_iid`, `sim_block_bootstrap`, `calibrate_ar1`, `calibrate_vasicek` |
| `mc_spec.R` | YAML lesen, Defaults, Validierung (checkmate, deutsche Meldungen) | `read_stochastic_spec`, `validate_stochastic_spec` |
| `mc_sample.R` | Szenarioobjekt (S3 `vofi_scenarios`), Pfadmerkmale, Teilmengen | `sample_stochastic`, `path_features`, `subset_scenarios` |
| `mc_apply.R` | Bindung `target` → Engine-Eingaben | `apply_scenarios` |
| `engine_*.R` | vektorisierte VoFi-Engine (eigenes Memo) | `vofi_engine(inputs, store = c("kpi", "bands", "full"))` |
| `mc_results.R` | Kennzahlen, Risikomaße, MC-Fehler, Dominanz | `mc_summary`, `quantile_ci`, `se_replicates`, `mc_convergence`, `dominance`, `compare_variants` |
| `mc_sensitivity.R` | Tornado, Spider, Break-even, globale Maße | `tornado`, `spider`, `break_even`, `src`, `prcc`, `first_order_binned` |
| `mc_plots.R` | ggplot2-Grafiken | `plot_fan`, `plot_hist_ecdf`, `plot_tornado`, `plot_convergence` |
| `tests/testthat/test-mc-*.R` | Abschnitt 9 | |

Zielbild der Nutzer-API:

```r
spec <- read_stochastic_spec("projekt_stochastik.yaml")
scen <- sample_stochastic(spec)                         # einmal je Analyse (CRN)
res  <- run_vofi(projekt, scenarios = scen, store = "bands")
summary(res)                                            # deutsche Zusammenfassung inkl. MC-Fehler
plot_fan(res, "bestandssaldo")
cmp  <- compare_variants(list(A = projekt_a, B = projekt_b), scenarios = scen)
sens <- sensitivity_global(res, kpi = "endwert_diff")
tor  <- tornado(projekt, spec, kpi = "endwert_diff", probs = c(0.1, 0.9))
```

**Reihenfolge:**

1. RNG, Verteilungen, Abhängigkeiten, Prozesse mit Tests (rein funktional, unabhängig von der Engine).
2. Spezifikation und Sampler.
3. Engine-Integration mit den Abnahmetests „degeneriert = deterministisch“ und „N = 1 = vektorisiert“.
4. Ergebnisse und Grafiken.
5. Sensitivität.
6. Kalibrierte Default-Bibliothek mit Quellen-Metadaten.
7. Optional: t-Copula, Sobol, Chunking, Parallelisierung.

---

## 12. Offene Fragen an den Auftraggeber

1. **Leitkennzahl und Hürden:** Soll primär der Endwert, die Endwertdifferenz zur Opportunität oder die VoFi-Rentabilität ausgewiesen werden? Welche Hürdenrenditen und Grenzen (DSCR, Belastungsquote, Kontokorrentlimit) gelten je Perspektive als Default?
2. **Undefinierte Rentabilität** (Endwert ≤ 0, Vollfinanzierung): Ist die Konvention „−100 % + Kennzeichnung“ akzeptabel?
3. **Default-Bibliothek:** Liefert das Tool kalibrierte Defaults mit Quellenangabe mit (Pflegeaufwand, Aktualisierungsrhythmus), oder muss der Nutzer alle Verteilungen selbst setzen? Wer verantwortet die Defaults fachlich?
4. **CO₂-Szenarien:** Sollen die Pfade und Wahrscheinlichkeiten vorgegeben werden (welche Studienbasis), oder nur das Format mit leeren Szenarien? Nominal oder real (der ETS-2-Preismechanismus ist in Preisen von 2020 definiert)?
5. **Realer Ausweis:** Sollen Kennzahlen zusätzlich inflationsbereinigt ausgewiesen werden (der Inflationspfad liegt je Simulation vor)?
6. **Variantenspezifische Risiken:** Gelten Kostenrisiken zweier Varianten als dasselbe Risiko (gleicher Name), als getrennte, aber korrelierte Risiken oder als unabhängig?
7. **Performance Gap:** Strukturmodell (Prebound/Rebound) oder vereinfachter Realisierungsfaktor als Default? Liegen typischerweise gemessene Verbräuche vor?
8. **Förderrisiko:** Nur Zusage ja/nein oder auch Programmänderungen und Zeitpunkt der Antragstellung (Förderstopp-Szenarien)?
9. **Zeitraster:** Reicht die Jahresrechnung, oder ist für die Bauphase (Bereitstellungszinsen, Verzug) eine Monatsrechnung nötig? Die Engine kann das; T = 960 wäre unkritisch.
10. **Interaktivität:** Welche Rechenzeit ist in der Shiny-Oberfläche akzeptabel (Vorschau mit N = 1.000 unter 0,2 s, Standard 10.000 unter 1 s)?
11. **Stresstests und Tail-Abhängigkeit:** Reichen deterministische Stresspfade und die Gauß-Copula in v1, oder wird eine t-Copula gewünscht?
12. **Warmmietenneutralität und Mieter–Vermieter-Aufteilung:** Gehört die Modellierung in das Struktur-Memo? Sie bestimmt, welche Unsicherheiten beim Vermieter überhaupt wirken.

---

## 13. Risiken

| Risiko | Wirkung | Gegenmaßnahme |
|---|---|---|
| **Scheingenauigkeit / Garbage in, garbage out** | Verteilungen sind überwiegend subjektiv; Nutzer lesen Wahrscheinlichkeiten als objektiv | Basisfall und MC nebeneinander; Quellen der Defaults anzeigen; MC-Fehler getrennt von inhaltlicher Streuung; Sensitivität der Ergebnisse auf Verteilungsannahmen (z. B. Szenariogewichte variieren) |
| **Fehlspezifizierte Abhängigkeiten** | Gauß-Copula ohne Tail-Abhängigkeit unterschätzt Extremszenarien wie 2022 | strukturelle Kopplungen; Stresspfade; t-Copula als Option; Plausibilitätsausgabe der realisierten Korrelationen |
| **Strukturbrüche und Regulierung über 40–80 Jahre** (GEG, BEHG/ETS 2, Mietrecht, Förderlandschaft) | nicht als stetiger Prozess modellierbar | Szenario-Mischungen und deterministische Szenarien statt scheinbar präziser Prozesse |
| **Doppelzählung von Unsicherheit** | Kopplung plus Korrelation, Trend- plus Volatilitätsunsicherheit doppelt kalibriert | Validierungsausgabe der resultierenden Momente und Korrelationen; Kalibrierdokumentation |
| **Disziplin im vektorisierten Code** | ein skalares `if` auf simulierte Werte erzeugt stille Fehler | Code-Regeln 5.1; Test „N = 1 vs. vektorisiert“ auf zufälligen Zeilen; Review |
| **Falsche Fehlerschätzung bei LHS** | naive SE 4-fach zu hoch bzw. falsch bei globalem Iman–Conover | replizierte LHS mit IC je Block (implementiert und getestet) |
| **Fehlinterpretation** von P(A > B) ohne CRN, Vorzeichen von VaR, Quantildifferenzen statt Differenzquantilen | Fehlentscheidungen | CRN erzwingen; Oberfläche zeigt Quantile der Differenz; klare deutsche Begriffe |
| **Sprungstellen** (Lebensdauern, Bernoulli, Stufenmodelle) | `uniroot`-Artefakte, nicht monotone Tornados | anteiliger Restwert; Sprungstellenprüfung; diskrete Größen gruppiert auswerten |
| **Tail-Kennzahlen bei zu kleinem N** | CVaR schwankt stark (Prototyp: −65 T€ vs. +74 T€) | N = 50.000 für Berichte; MC-Fehler ausweisen |
| **Speicher bei großen N×T** | 1,9 GB für volle Tabellen bei N = 100.000, T = 80 | Streaming-Bänder; volle Tabellen nur für ausgewählte Läufe; Chunking |
| **Reproduzierbarkeit über R-Versionen** | geänderte RNG-Defaults | RNG-Varianten explizit setzen; Metadaten speichern; Snapshot-Tests |
| **Locale/Encoding** | YAML mit Umlauten scheitert unter Locale `C` | locale-robustes Lesen (10.1) |
| **Zeitlich instabile Kalibrierung** | Defaults (z. B. θ, CO₂-Pfade) veralten | Metadaten mit Abrufdatum; Warnung bei Defaults älter als 12 Monate |

---

## 14. Quellen

**Methodik**

- Grob, H. L.: *Einführung in die Investitionsrechnung – Eine Fallstudiengeschichte*, Vahlen (VoFi-Methodik).
- McKay, M. D.; Beckman, R. J.; Conover, W. J. (1979): A Comparison of Three Methods for Selecting Values of Input Variables in the Analysis of Output from a Computer Code. *Technometrics* 21(2).
- Stein, M. (1987): Large Sample Properties of Simulations Using Latin Hypercube Sampling. *Technometrics* 29(2).
- Iman, R. L.; Conover, W. J. (1982): A distribution-free approach to inducing rank correlation among input variables. *Communications in Statistics – Simulation and Computation* 11(3).
- Higham, N. J. (2002): Computing the nearest correlation matrix – a problem from finance. *IMA Journal of Numerical Analysis* 22(3).
- Vasicek, O. (1977): An equilibrium characterization of the term structure. *Journal of Financial Economics* 5(2).
- Schwartz, E. S. (1997): The Stochastic Behavior of Commodity Prices. *Journal of Finance* 52(3).
- Glasserman, P. (2003): *Monte Carlo Methods in Financial Engineering*, Springer (Varianzreduktion, CRN, antithetische Variablen).
- L'Ecuyer, P. et al. (2002): An Object-Oriented Random-Number Package with Many Long Streams and Substreams. *Operations Research* 50(6).
- Künsch, H. R. (1989): The Jackknife and the Bootstrap for General Stationary Observations. *Annals of Statistics* 17(3).
- Politis, D. N.; Romano, J. P. (1994): The Stationary Bootstrap. *JASA* 89(428).
- Saltelli, A. et al. (2008): *Global Sensitivity Analysis. The Primer*, Wiley.
- Marino, S. et al. (2008): A methodology for performing global uncertainty and sensitivity analysis in systems biology. *Journal of Theoretical Biology* 254(1) (PRCC).
- Vose, D. (2008): *Risk Analysis – A Quantitative Guide*, 3. Aufl., Wiley (PERT, Expertenschätzung).
- Hyndman, R. J.; Fan, Y. (1996): Sample Quantiles in Statistical Packages. *The American Statistician* 50(4).

**Performance Gap**

- Sunikka-Blank, M.; Galvin, R. (2012): Introducing the prebound effect: the gap between performance and actual energy consumption. *Building Research & Information* 40(3). [PDF](https://www.arct.cam.ac.uk/system/files/documents/introducing-the-prebound-effect-the-gap-between-performance-and-actual-energy-consumption-minna-sunikka-blank-and-ray-galvin.pdf), [University of Cambridge – The prebound effect](https://www.cam.ac.uk/research/news/the-prebound-effect)
- Galvin, R.; Sunikka-Blank, M. (2013): *A Critical Appraisal of Germany's Thermal Retrofit Policy*, Springer.
- Cozza, S. et al. (2019), Schweiz: realisierte Einsparungen 37 % unter Rechenwert (zitiert nach [Frontiers in Built Environment 2020](https://www.frontiersin.org/journals/built-environment/articles/10.3389/fbuil.2020.609877/epub)).

**Daten und Rahmenbedingungen** (abgerufen 25.10.2026)

- Deutsche Bundesbank, MFI-Zinsstatistik, SUD119 (BBIM1.M.DE.B.A2C.P.R.A.2250.EUR.N): [Wohnungsbaukredite an private Haushalte](https://www.bundesbank.de/de/statistiken/geld-und-kapitalmaerkte/zinssaetze-und-renditen/wohnungsbaukredite-an-private-haushalte-hypothekarkredite-auf-wohngrundstuecke-615036); abgerufen über `api.statistiken.bundesbank.de` (Stand der Reihe 01.10.2026, letzter Wert 08/2026).
- EZB Data Portal, HVPI Deutschland (ICP.M.DE.N.000000.4.ANR; Teilindizes 041000, 045100, 045200, 045300, 045500, INX), `data-api.ecb.europa.eu`.
- Eurostat, Construction producer prices or costs (sts_copi_a), DE, PRC_PRR, CPA_F41001_X_410014, `ec.europa.eu/eurostat/api`.
- Bundestag, hib 692/2026 (08.09.2026), Gesetzentwurf BEHG/CO₂-Preis 2027: [bundestag.de/1210950](https://www.bundestag.de/1210950); Advant Beiten: [BEHG-Novelle: CO₂-Preis bleibt 2027 im Korridor von 55 bis 65 Euro](https://www.advant-beiten.com/aktuelles/behg-novelle-co2-preis-bleibt-2027-im-korridor-von-55-bis-65-euro); EY: [Referentenentwurf 3. BEHG-Änderungsgesetz](https://www.ey.com/de_de/technical/steuernachrichten/referentenentwurf-zum-dritten-behg-aenderungsgesetz-stabilisierung-des-co2-preises-fuer-2027); ZfK: [CO₂-Preis 2027 – Einigung Union/SPD](https://www.zfk.de/politik/deutschland/co2-preis-2027-einigung-union-spd-behg-ets2); FÖS Policy Brief 07/2026: [Eingefrorener CO₂-Preis 2027](https://foes.de/publikationen/2026/2026-07-FOES_Policy_Brief_Eingefrorener_CO2-Preis_2027.pdf).
- ETS-2-Preisprognosen: Rödl & Partner (11/2025): [ETS 2 verzögert – Klimakosten bleiben](https://www.roedl.com/insights/ets-2-verzoegert-klimakosten-bleiben-warum-sie-nicht-auf-die-politik-warten-sollten-2/); Carbon Pulse: [Analysts see ETS2 … prices at €100/t](https://carbon-pulse.com/392388/), [EU ETS2 prices seen hitting €200 mark by 2030](https://carbon-pulse.com/271109); Ariadne-Werte (275 €/t, 140–405 €/t) nur über Sekundärquellen, z. B. [Tagesspiegel Background](https://background.tagesspiegel.de/energie-und-klima/briefing/hohe-co2-preise-fuer-eu-klimaziel-notwendig). **Den Originalbericht vor Übernahme prüfen.**
- Aktuelle Bauzinsen (Anbieterangaben, nur Plausibilisierung): [Dr. Klein](https://www.drklein.de/finanzlexikon/darlehenszinsen.html), [Schwäbisch Hall](https://www.schwaebisch-hall.de/baufinanzierung/bauzinsen-aktuell.html).
- Rechtsgrundlagen, im Rechts-Memo zu prüfen: CO2KostAufG (Stufenmodell, Anlage), §§ 557b, 558, 559, 559e BGB, § 489 BGB, BEHG, II. BV § 29 (Mietausfallwagnis), BNB-Nutzungsdauern.

---

## Anhang A: Prototyp der vektorisierten VoFi-Engine (Benchmark-Grundlage)

Die Engine ist bewusst kompakt gehalten und fachlich vereinfacht (z. B. keine Bereitstellungszinsen, keine Steuern). Sie zeigt die Vektorisierungsmuster und ist kein Vorschlag für das endgültige Fachmodell.

```r
annuity <- function(B, i, n) ifelse(abs(i) < 1e-12, B / n, B * i / (1 - (1 + i)^(-n)))

vofi_engine <- function(sc, par, store = c("kpi", "bands", "full"),
                        probs = c(0.05, 0.25, 0.5, 0.75, 0.95)) {
  store <- match.arg(store)
  T <- par$T; N <- length(sc$cost_factor)
  rows <- c("investition", "miete", "leerstand", "instandhaltung", "verwaltung",
            "co2_vermieter", "ersatzinvestition", "restwert", "zahlungsreihe",
            "eigenkapital", "d1_aufnahme", "d1_zins", "d1_tilgung",
            "d2_aufnahme", "d2_zins", "d2_tilgung", "d2_tilgungszuschuss",
            "kk_aufnahme", "kk_rueckfuehrung", "kk_zins",
            "ga_anlage", "ga_aufloesung", "ga_zins", "finanzierungssaldo",
            "bestand_d1", "bestand_d2", "bestand_kk", "bestand_ga", "bestandssaldo")
  full <- if (store == "full") lapply(setNames(rows, rows), function(r) matrix(0, N, T + 1)) else NULL
  bands <- if (store != "kpi") list(bestandssaldo = matrix(NA, T + 1, length(probs)),
                                    bestand_kk    = matrix(NA, T + 1, length(probs)),
                                    dscr          = matrix(NA, T + 1, length(probs))) else NULL
  rec <- function(name, t, x) if (!is.null(full)) full[[name]][, t + 1] <<- x

  B1 <- B2 <- KK <- GA <- numeric(N)                        # Zustände: Vektoren der Länge N
  i1 <- rep(par$i1, N); A1 <- rep(par$loan1 * (par$i1 + par$tilg1), N)
  n1 <- -log(1 - par$i1 * par$loan1 / A1[1]) / log(1 + par$i1)
  tilg2 <- numeric(N)
  rent_idx <- cost_idx <- infl_idx <- rep(1, N)
  L <- pmax(round(sc$lifetime_hp), 1)
  min_dscr <- rep(Inf, N); kk_max <- numeric(N); noi <- numeric(N)

  for (t in 0:T) {
    z <- ek <- d1in <- d2in <- z1 <- t1 <- z2 <- t2 <- tz2 <- kkz <- gaz <- numeric(N)
    if (t == 0) {
      inv <- -par$invest_base * sc$cost_factor
      z <- inv; ek <- rep(par$ek0, N); d1in <- rep(par$loan1, N); d2in <- rep(par$loan2, N)
      rec("investition", t, inv)
    } else {
      rent_idx <- rent_idx * (1 + sc$rent_g[, t])
      cost_idx <- cost_idx * (1 + sc$constr_g[, t])
      infl_idx <- infl_idx * (1 + sc$infl[, t])
      occ   <- pmin(pmax(t - sc$delay_m / 12, 0), 1)                     # Bauzeitverzug
      miete <- par$rent0 * rent_idx * occ
      leer  <- -miete * sc$vac[, t]
      inst  <- -par$maint0 * cost_idx
      verw  <- -par$mgmt0 * infl_idx
      co2   <- -sc$co2[, t] * par$co2_t_base * (1 - par$saving * sc$perf_factor) * par$landlord_share
      ers   <- -par$hp_cost * cost_idx * ((t %% L) == 0)                # Ersatz nach Lebensdauer
      noi   <- miete + leer + inst + verw + co2
      rw <- numeric(N)
      if (t == T) {                                                     # Restwert, Exit an Zins gekoppelt
        y_exit <- pmax(par$exit_yield0 + par$exit_beta * (sc$rate[, T] - par$i1) + sc$exit_eps, 0.02)
        rw <- noi * (1 + sc$rent_g[, T]) / y_exit
      }
      z <- noi + ers + rw
      rec("miete", t, miete); rec("leerstand", t, leer); rec("instandhaltung", t, inst)
      rec("verwaltung", t, verw); rec("co2_vermieter", t, co2); rec("ersatzinvestition", t, ers)
      rec("restwert", t, rw)
      if (t > 1 && (t - 1) %% par$binding1 == 0) {                      # Anschlussfinanzierung
        i1 <- sc$rate[, t - 1] + par$spread1
        A1 <- annuity(B1, i1, pmax(n1 - (t - 1), 1))
      }
      z1 <- -B1 * i1
      t1 <- -pmin(pmax(A1 + z1, 0), B1)
      if (t == 1) { tz2 <- pmin(par$subsidy * sc$subsidy_ok, B2); B2 <- B2 - tz2 }   # Tilgungszuschuss
      if (t == par$free2 + 1) tilg2 <- B2 / (par$term2 - par$free2)
      z2 <- -B2 * par$i2
      t2 <- -pmin(if (t > par$free2) tilg2 else 0, B2)
      kkz <- -KK * (sc$rate[, t] + par$kk_spread)                       # Zinsen auf Vorperiodenbestand
      gaz <- GA * sc$dep_rate[, t]
      ds  <- -(z1 + t1 + z2 + t2)
      dscr <- ifelse(ds > 0, noi / ds, Inf)
      min_dscr <- pmin(min_dscr, dscr)
    }
    pre <- z + ek + d1in + d2in + z1 + t1 + z2 + t2 + kkz + gaz          # Ausgleichsregel
    net <- pre + GA - KK
    GA_new <- pmax(net, 0); KK_new <- pmax(-net, 0)
    kk_auf <- pmax(KK_new - KK, 0); kk_rf <- -pmax(KK - KK_new, 0)
    ga_an <- -pmax(GA_new - GA, 0); ga_auf <- pmax(GA - GA_new, 0)
    B1 <- B1 + d1in + t1; B2 <- B2 + d2in + t2
    KK <- KK_new; GA <- GA_new
    kk_max <- pmax(kk_max, KK)
    saldo <- GA - KK - B1 - B2
    if (!is.null(full)) {
      rec("zahlungsreihe", t, z); rec("eigenkapital", t, ek)
      rec("d1_aufnahme", t, d1in); rec("d1_zins", t, z1); rec("d1_tilgung", t, t1)
      rec("d2_aufnahme", t, d2in); rec("d2_zins", t, z2); rec("d2_tilgung", t, t2)
      rec("d2_tilgungszuschuss", t, tz2)
      rec("kk_aufnahme", t, kk_auf); rec("kk_rueckfuehrung", t, kk_rf); rec("kk_zins", t, kkz)
      rec("ga_anlage", t, ga_an); rec("ga_aufloesung", t, ga_auf); rec("ga_zins", t, gaz)
      rec("finanzierungssaldo", t, pre + kk_auf + kk_rf + ga_an + ga_auf)
      rec("bestand_d1", t, B1); rec("bestand_d2", t, B2); rec("bestand_kk", t, KK)
      rec("bestand_ga", t, GA); rec("bestandssaldo", t, saldo)
    }
    if (!is.null(bands)) {                                               # Fächerbänder im Streaming
      bands$bestandssaldo[t + 1, ] <- quantile(saldo, probs, names = FALSE)
      bands$bestand_kk[t + 1, ]    <- quantile(KK, probs, names = FALSE)
      if (t > 0) bands$dscr[t + 1, ] <- quantile(dscr, probs, names = FALSE)
    }
  }
  ew <- saldo
  ew_opp <- par$ek0 * apply(1 + sc$dep_rate[, 1:T, drop = FALSE], 1, prod)   # Opportunität, gleicher Pfad
  kpi <- data.frame(endwert = ew, endwert_opp = ew_opp, endwert_diff = ew - ew_opp,
                    vofi_rendite = ifelse(ew > 0, (ew / par$ek0)^(1 / T) - 1, NA_real_),
                    min_dscr = min_dscr, kk_max = kk_max, liquiditaetsengpass = kk_max > par$kk_limit)
  list(kpi = kpi, bands = bands, full = full)
}

# Szenario-Generator des Prototyps (Annahmen nur zur Demonstration)
gen_scenarios <- function(N, T, seed, method = "lhs", antithetic = FALSE, degenerate = FALSE,
                          replicates = if (method == "lhs") 10L else 1L) {
  if (degenerate) {
    return(list(cost_factor = rep(1, N), delay_m = rep(0, N), subsidy_ok = rep(1, N),
                perf_factor = rep(0.8, N), lifetime_hp = rep(18, N), exit_eps = rep(0, N),
                infl = matrix(0.02, N, T), rent_g = matrix(0.02, N, T), constr_g = matrix(0.025, N, T),
                rate = matrix(0.035, N, T), dep_rate = matrix(0.02, N, T),
                co2 = matrix(rep(seq(65, 250, length.out = T), each = N), N, T), vac = matrix(0.02, N, T)))
  }
  du <- function(nm) draw_u(N, seed, nm, method, antithetic, replicates)
  X <- cbind(q_pert(du("cost_factor"), 0.95, 1.05, 1.40), q_pert(du("delay_m"), 0, 2, 12))
  X <- iman_conover(X, matrix(c(1, 0.5, 0.5, 1), 2), seed, "ic:bau", replicates)
  sh <- function(nm) draw_shocks(N, T, seed, nm, method, antithetic, replicates)
  Zs <- correlate_shocks(list(infl = sh("infl"), rate = sh("rate"), rent = sh("rent"), constr = sh("constr")),
                         matrix(c(1, .4, .5, .6,  .4, 1, .2, .3,  .5, .2, 1, .3,  .6, .3, .3, 1), 4))
  infl <- sim_ar1(Zs$infl, 0.02, 0.6, 0.010, x0 = 0.022)
  rate <- sim_vasicek(Zs$rate, 0.039, 0.040, 0.15, 0.008, floor = 0.005)
  paths <- rbind(approx(c(0, 4, 19, 40), c(60, 70, 90, 100),   xout = 1:T, rule = 2)$y,
                 approx(c(0, 4, 19, 40), c(60, 120, 200, 250), xout = 1:T, rule = 2)$y,
                 approx(c(0, 4, 19, 40), c(60, 200, 300, 350), xout = 1:T, rule = 2)$y)
  list(cost_factor = X[, 1], delay_m = X[, 2],
       subsidy_ok  = as.numeric(du("subsidy_ok") < 0.85),
       perf_factor = q_pert(du("perf_factor"), 0.4, 0.8, 1.05),
       lifetime_hp = q_pert(du("lifetime_hp"), 12, 18, 25),
       exit_eps    = qnorm(du("exit_eps"), 0, 0.004),
       infl = infl,
       rent_g   = 0.002 + 0.8 * infl + sim_ar1(Zs$rent, 0, 0.5, 0.006),
       constr_g = 0.005 + infl + sim_ar1(Zs$constr, 0, 0.5, 0.015),
       rate = rate, dep_rate = pmax(rate - 0.015, 0),
       co2 = sim_scenario_mix(du("co2_scenario"), paths, c(.3, .5, .2), Z = sh("co2"), sigma = .15, phi = .8),
       vac = sim_iid(matrix(draw_u(N * T, seed, "vac", "pseudo"), N, T),
                     tabulate_qf(function(u) q_pert(u, 0, 0.02, 0.10))))
}

par_default <- list(T = 40, invest_base = 3.0e6, ek0 = 1.15e6, loan1 = 1.5e6, i1 = 0.039, tilg1 = 0.015,
                    binding1 = 10, spread1 = 0.0, loan2 = 0.5e6, i2 = 0.025, term2 = 20, free2 = 2,
                    subsidy = 0.075e6, rent0 = 0.18e6, maint0 = 0.025e6, mgmt0 = 0.012e6,
                    co2_t_base = 60, saving = 0.7, landlord_share = 0.5, hp_cost = 0.12e6,
                    kk_spread = 0.04, kk_limit = 0.15e6, exit_yield0 = 0.04, exit_beta = 0.5)
```

Beispielergebnis des Prototyps (N = 10.000, LHS; Zahlen nur zur Illustration):

- Endwert: Median 11,6 Mio. €, P5 6,7 Mio. €, Mittelwert 11,6 Mio. € (± 0,06 Mio. € MC-Fehler, naiv); Basisfall 14,3 Mio. €
- P(Endwert < Opportunität) 1,7 %
- P(min DSCR < 1) 47 %, vor allem im ersten Jahr durch Bauzeitverzug
- P(Kontokorrent > Limit) 45 %, vor allem durch Kostenüberschreitung bei t = 0
- Anteil undefinierter VoFi-Renditen 0,6 %

Der Basisfall liegt deutlich über dem MC-Median. Grund sind die Annahmen der Demo: Im Basisfall gibt es keinen Verzug, keine Kostenüberschreitung und einen niedrigeren Zins, während die Verteilungen nach oben schief sind. Das ist der Jensen- bzw. Schiefe-Effekt aus Abschnitt 1.1.
