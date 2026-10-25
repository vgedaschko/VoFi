#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VoFi-Referenzrechner (Testorakel fuer die R-Engine)
Memo docs/recherche/01_vofi_methodik.md, Stand 2026-10-25.
Reines Python 3 (keine Zusatzpakete). Aufruf: python3 vofi_ref.py
Konventionen: siehe Abschnitt 10.1 des Memos (K1-K14).
"""
INF = float("inf")
EPS = 1e-9


def per(x, T):
    """Skalar oder Liste -> Liste der Laenge T+1 (Index t = 0..T)."""
    if isinstance(x, (int, float)):
        return [float(x)] * (T + 1)
    assert len(x) == T + 1, "Laenge muss T+1 sein"
    return [float(v) for v in x]


class Loan:
    """Darlehen als Zustandsautomat.
    kind      : 'annuity' | 'installment' | 'bullet'
    disb      : {t: Nennbetrag} Auszahlungen (Teilvalutierung moeglich)
    rate      : Periodenzinssatz (Skalar oder Liste T+1; Index t = Zins der Periode t auf Stand t-1)
    term      : Laufzeit in Perioden ab erster Periode nach letzter Auszahlung (inkl. tilgungsfreier
                Perioden); None = bis zur vollstaendigen Tilgung (nur annuity/init_tilg)
    grace     : tilgungsfreie Anlaufperioden
    init_tilg : anfaenglicher Tilgungssatz je Periode (Annuitaet = Nennbetrag*(Zins+init_tilg))
    payout    : Auszahlungskurs (1.0 = 100 %)
    tz, tz_t  : Tilgungszuschuss (Betrag) und Periode der Gutschrift (nach planmaessiger Zahlung)
    tz_effect : 'shorten_term' (Rate bleibt, Laufzeit verkuerzt) | 'reduce_installment'
    commit_fee, fee_from : Bereitstellungsprovision je Periode auf nicht abgerufenen Betrag ab Periode fee_from
    """

    def __init__(self, name, kind, disb, rate, term=None, grace=0, init_tilg=None,
                 payout=1.0, tz=0.0, tz_t=None, tz_effect="shorten_term",
                 commit_fee=0.0, fee_from=10**9):
        self.name, self.kind, self.disb = name, kind, dict(disb)
        self.rate_in, self.term, self.grace = rate, term, grace
        self.init_tilg, self.payout = init_tilg, payout
        self.tz, self.tz_t, self.tz_effect = tz, tz_t, tz_effect
        self.commit_fee, self.fee_from = commit_fee, fee_from
        self.commitment = sum(self.disb.values())
        self.first = max(self.disb) + 1               # erste Periode nach letzter Auszahlung
        self.rep_start = self.first + grace            # erste Tilgungsperiode
        self.mat = None if term is None else self.first + term - 1  # Faelligkeit

    def reset(self, T):
        self.rate = per(self.rate_in, T)
        self.B, self.drawn, self.A, self.R = 0.0, 0.0, None, None

    def step(self, t):
        """Gibt (Auszahlung, Zins, Provision, Tilgung, TZ) der Periode t zurueck."""
        B0 = self.B
        r = self.rate[t]
        zins = r * B0 if t > 0 else 0.0
        fee = 0.0
        if t > 0 and t >= self.fee_from:
            fee = self.commit_fee * (self.commitment - self.drawn)
        tilg = 0.0
        if t >= self.rep_start and B0 > EPS:
            if self.kind == "annuity":
                if self.A is None:
                    basis = self.commitment if self.tz_effect == "shorten_term" else B0
                    if self.init_tilg is not None:
                        self.A = basis * (r + self.init_tilg)
                    else:
                        n = self.mat - self.rep_start + 1
                        self.A = basis * r / (1 - (1 + r) ** (-n)) if r != 0 else basis / n
                tilg = min(self.A - zins, B0)
            elif self.kind == "installment":
                if self.R is None:
                    basis = self.commitment if self.tz_effect == "shorten_term" else B0
                    self.R = basis / (self.mat - self.rep_start + 1)
                tilg = min(self.R, B0)
            if self.mat is not None and t == self.mat:
                tilg = B0                                  # Schlusszahlung / endfaellig
        d = self.disb.get(t, 0.0)
        self.drawn += d
        self.B = B0 - tilg + d
        tz = 0.0
        if self.tz_t is not None and t == self.tz_t and self.tz > 0:
            tz = min(self.tz, self.B)
            self.B -= tz
            if self.tz_effect == "reduce_installment" and t >= self.rep_start and self.B > EPS:
                n_rem = self.mat - t
                r1 = self.rate[min(t + 1, len(self.rate) - 1)]
                if self.kind == "annuity":
                    self.A = self.B * r1 / (1 - (1 + r1) ** (-n_rem))
                elif self.kind == "installment":
                    self.R = self.B / n_rem
        return d * self.payout, zins, fee, tilg, tz


def vofi(T, z, loans=(), einlagen=0.0, entnahmen=0.0, zuschuesse=0.0, steuern=0.0,
         h=0.0, s=0.0, kk_limit=INF, policy="unlimited", sonder=()):
    """Rechnet einen VoFi. h, s = Haben-/Sollzins (KK) je Periode (Skalar oder Liste T+1).
    policy bei Ueberschreiten von kk_limit: 'equity_call' (Nachschuss als Einlage) | 'stop'.
    sonder: Namen der Darlehen, die aus Ueberschuessen (nach KK-Tilgung) sondergetilgt werden
            duerfen (Reihenfolge: hoechster Periodenzins zuerst, nur wenn Zins > Habenzins)."""
    z, einl, entn = per(z, T), per(einlagen, T), per(entnahmen, T)
    zus, st, h, s = per(zuschuesse, T), per(steuern, T), per(h, T), per(s, T)
    for L in loans:
        L.reset(T)
    R = {k: [0.0] * (T + 1) for k in
         ["z", "einl", "nachschuss", "entn", "zus", "steuern", "kk_auf", "kk_tilg", "kk_zins",
          "anlage", "aufl", "hz", "saldo", "G", "KK", "BS", "S_vor"]}
    for L in loans:
        for k in ["auf", "zins", "fee", "tilg", "st", "tz", "B"]:
            R[L.name + "_" + k] = [0.0] * (T + 1)
    G0 = KK0 = 0.0
    for t in range(T + 1):
        flows = z[t] + einl[t] - entn[t] + zus[t] - st[t]
        debt = 0.0
        for L in loans:
            auf, zins, fee, tilg, tz = L.step(t)
            R[L.name + "_auf"][t] = auf
            R[L.name + "_zins"][t] = -zins
            R[L.name + "_fee"][t] = -fee
            R[L.name + "_tilg"][t] = -tilg
            R[L.name + "_tz"][t] = tz
            R[L.name + "_B"][t] = L.B
            flows += auf - zins - fee - tilg
            debt += L.B
        hz = h[t] * G0 if t > 0 else 0.0
        kz = s[t] * KK0 if t > 0 else 0.0
        S = flows + hz - kz
        R["S_vor"][t] = S
        kk_auf = kk_tilg = anlage = aufl = nach = 0.0
        if S >= 0:                       # Ueberschuss: 1. KK tilgen, 2. Sondertilgung, 3. anlegen
            kk_tilg = min(S, KK0)
            rest = S - kk_tilg
            for L in sorted([L for L in loans if L.name in sonder], key=lambda L: -L.rate[t]):
                if rest <= EPS or t == 0 or L.rate[t] <= h[t]:
                    continue
                st_amt = min(rest, L.B)
                L.B -= st_amt
                rest -= st_amt
                debt -= st_amt
                R[L.name + "_st"][t] = -st_amt
                R[L.name + "_B"][t] = L.B
            anlage = rest
        else:                            # Defizit: 1. Guthaben aufloesen, 2. KK bis Limit, 3. Policy
            need = -S
            aufl = min(need, G0)
            need -= aufl
            kk_auf = min(need, max(kk_limit - KK0, 0.0))
            need -= kk_auf
            if need > EPS:
                if policy == "equity_call":
                    nach = need
                else:
                    raise RuntimeError("Liquiditaetsengpass in Periode %d" % t)
        G = G0 + anlage - aufl
        KK = KK0 + kk_auf - kk_tilg
        R["z"][t], R["einl"][t], R["nachschuss"][t] = z[t], einl[t], nach
        R["entn"][t], R["zus"][t], R["steuern"][t] = -entn[t], zus[t], -st[t]
        R["kk_auf"][t], R["kk_tilg"][t], R["kk_zins"][t] = kk_auf, -kk_tilg, -kz
        R["anlage"][t], R["aufl"][t], R["hz"][t] = -anlage, aufl, hz
        R["G"][t], R["KK"][t], R["BS"][t] = G, KK, G - KK - debt
        st_sum = sum(R[L.name + "_st"][t] for L in loans)
        R["saldo"][t] = flows + st_sum + hz - kz + nach + kk_auf - kk_tilg - anlage + aufl
        G0, KK0 = G, KK
    R["_T"], R["_einl_tot"], R["_entn"] = T, [e + n for e, n in zip(einl, R["nachschuss"])], entn
    R["_h"], R["_s"] = h, s
    return R


# ---------- Kennzahlen ----------
def bisect(f, lo, hi, tol=1e-12, it=300):
    flo = f(lo)
    for _ in range(it):
        mid = 0.5 * (lo + hi)
        fm = f(mid)
        if (fm > 0) == (flo > 0):
            lo, flo = mid, fm
        else:
            hi = mid
        if hi - lo < tol:
            break
    return 0.5 * (lo + hi)


def npv(cf, i, tau=None):
    tau = tau or list(range(len(cf)))
    return sum(c / (1 + i) ** u for c, u in zip(cf, tau))


def irr(cf, tau=None, lo=-0.99, hi=1.0):
    f = lambda r: npv(cf, r, tau)
    if f(lo) * f(hi) > 0:
        return None
    return bisect(f, lo, hi)


def kpis(res, tau, restwert=0.0, noi=None, value=None, kd_loans=None):
    """tau: Zeitpunkte in Jahren (Liste T+1). restwert: im z_T enthaltener Restwert."""
    T = res["_T"]
    h = res["_h"]
    einl, entn = res["_einl_tot"], res["_entn"]
    EW = res["BS"][T]
    # Unterlassungsalternative: gleiche Einlagen/Entnahmen, keine Investition, keine Kredite
    U = vofi(T, 0.0, (), einlagen=einl, entnahmen=entn, h=h, s=res["_s"])
    EW_U = U["BS"][T]
    EK0 = einl[0]
    Ty = tau[T] - tau[0]
    out = {"EW": EW, "EW_U": EW_U, "dEW": EW - EW_U, "EK0": EK0}
    out["rEK_klass"] = (EW / EK0) ** (1 / Ty) - 1 if EK0 > 0 and EW > 0 and sum(einl[1:]) == 0 and sum(entn) == 0 else None
    # modifizierte VoFi-EK-Rendite (R3): Entnahmen mit h aufgezinst, Einlagen mit h abgezinst
    acc = [1.0] * (T + 1)                       # Aufzinsfaktor 0 -> t mit Periodenhabenzins
    for t in range(1, T + 1):
        acc[t] = acc[t - 1] * (1 + h[t])
    num = EW + sum(entn[t] * acc[T] / acc[t] for t in range(T + 1))
    den = sum(einl[t] / acc[t] for t in range(T + 1))
    out["rEK_mod"] = (num / den) ** (1 / Ty) - 1 if den > EPS and num > 0 else None
    # Equity-IRR (R2)
    cf = [-einl[t] + entn[t] for t in range(T + 1)]
    cf[T] += EW
    out["rEK_irr"] = irr(cf, tau) if den > EPS else None
    # Amortisation (dauerhaft BS_t >= BS^U_t)
    def amort(bs):
        ta = None
        for t in range(T, -1, -1):
            if bs[t] >= U["BS"][t] - 1e-9:
                ta = tau[t]
            else:
                break
        return ta
    out["t_amort"] = amort(res["BS"])
    bs_ohne = res["BS"][:]
    bs_ohne[T] -= restwert
    out["t_amort_ohneRW"] = amort(bs_ohne)
    out["BS_U"] = U["BS"]
    out["minLiq"] = min(g - k for g, k in zip(res["G"], res["KK"]))
    out["maxKK"] = max(res["KK"])
    out["sum_nachschuss"] = sum(res["nachschuss"])
    if noi is not None and kd_loans is not None:
        dscr, ltv = [None], [None]
        for t in range(1, T + 1):
            kd = sum(-(res[n + "_zins"][t] + res[n + "_tilg"][t]) for n in kd_loans)
            dscr.append(noi[t] / kd if kd > EPS else None)
        out["DSCR"] = dscr
    if value is not None and kd_loans is not None:
        out["LTV"] = [(sum(res[n + "_B"][t] for n in kd_loans) + res["KK"][t]) / value[t]
                      for t in range(T + 1)]
    return out


def entnahme_aequivalent(run, EW_U, T):
    """Konstante Zusatzentnahme E (t=1..T), so dass EW(E) = EW_U. run(E) -> Ergebnis-Dict."""
    f = lambda E: run(E)["BS"][T] - EW_U
    lo, hi = -1e7, 1e7
    return bisect(f, lo, hi, tol=1e-10)


def check(res, loans):
    """Invarianten: (1) Finanzierungssaldo = 0 je Periode;
    (2) Vermoegensfortschreibung: BS_t - BS_{t-1} = z + Einlagen + Nachschuss - Entnahmen + Zuschuesse
        - Steuern - Sollzinsen - Provisionen - Disagio + Habenzinsen + Tilgungszuschuss."""
    T = res["_T"]
    e1 = max(abs(v) for v in res["saldo"])
    e2 = 0.0
    for t in range(T + 1):
        d = res["BS"][t] - (res["BS"][t - 1] if t > 0 else 0.0)
        flow = (res["z"][t] + res["einl"][t] + res["nachschuss"][t] + res["entn"][t] + res["zus"][t]
                + res["steuern"][t] + res["kk_zins"][t] + res["hz"][t])
        for L in loans:
            nominal = L.disb.get(t, 0.0)
            flow += (res[L.name + "_zins"][t] + res[L.name + "_fee"][t] + res[L.name + "_tz"][t]
                     + (res[L.name + "_auf"][t] - nominal))
        e2 = max(e2, abs(d - flow))
    return e1, e2


def unlevered(T, z, h, s):
    """VoFi ohne Fremdkapital: EK = Investitionsauszahlung in t=0 (financing-neutrale Projektsicht)."""
    I0 = -z[0]
    r = vofi(T, z, (), einlagen=[I0] + [0.0] * T, h=h, s=s)
    EW = r["BS"][T]
    return EW, ((EW / I0) ** (1.0 / T) - 1 if EW > 0 else None)


# ---------- Ausgabe ----------
def fmt(x):
    if x is None:
        return "n. d."
    if abs(x) < 5e-10:
        return "–"
    s = "{:,.2f}".format(x)
    return s.replace(",", "X").replace(".", ",").replace("X", ".")


def pct(x, d=4):
    return "n. d." if x is None else ("{:." + str(d) + "f} %").format(100 * x).replace(".", ",")


def table(res, loans, extra_rows=(), header="t", tau_labels=None):
    T = res["_T"]
    cols = tau_labels or [str(t) for t in range(T + 1)]
    lines = ["| Position | " + " | ".join(cols) + " |",
             "|---|" + "---:|" * (T + 1)]
    def row(label, key, show_if_nonzero=False):
        vals = res[key]
        if show_if_nonzero and all(abs(v) < 5e-10 for v in vals):
            return
        lines.append("| " + label + " | " + " | ".join(fmt(v) for v in vals) + " |")
    row("Zahlungsfolge z_t", "z")
    for lab, key in extra_rows:
        row(lab, key)
    row("Zuschüsse (zahlungswirksam)", "zus", True)
    row("EK: Einlage", "einl")
    row("EK: Nachschuss (endogen)", "nachschuss", True)
    row("EK: Entnahme", "entn", True)
    for L in loans:
        row(L.name + ": Aufnahme", L.name + "_auf")
        row(L.name + ": Tilgung", L.name + "_tilg")
        row(L.name + ": Sondertilgung", L.name + "_st", True)
        row(L.name + ": Sollzinsen", L.name + "_zins")
        row(L.name + ": Bereitstellungsprov.", L.name + "_fee", True)
    row("Kontokorrent: Aufnahme", "kk_auf")
    row("Kontokorrent: Tilgung", "kk_tilg")
    row("Kontokorrent: Sollzinsen", "kk_zins")
    row("Geldanlage: Anlage", "anlage")
    row("Geldanlage: Auflösung", "aufl")
    row("Geldanlage: Habenzinsen", "hz")
    row("Steuern (Slot, v1 = 0)", "steuern")
    row("**Finanzierungssaldo**", "saldo")
    for L in loans:
        row(L.name + ": Tilgungszuschuss (zahlungsunwirksam)", L.name + "_tz", True)
        row("Bestand " + L.name, L.name + "_B")
    row("Bestand Kontokorrent", "KK")
    row("Bestand Guthaben", "G")
    row("**Bestandssaldo**", "BS")
    return "\n".join(lines)


def show_kpis(k, title):
    print("\n**Kennzahlen " + title + "**\n")
    print("| Kennzahl | Wert |\n|---|---:|")
    print("| VoFi-Endwert EW | " + fmt(k["EW"]) + " |")
    print("| Endwert Unterlassungsalternative EW_U | " + fmt(k["EW_U"]) + " |")
    print("| Endwertdifferenz ΔEW = EW − EW_U | " + fmt(k["dEW"]) + " |")
    print("| VoFi-EK-Rentabilität klassisch (EW/EK0)^(1/T)−1 | " + pct(k["rEK_klass"]) + " |")
    print("| modifizierte VoFi-EK-Rendite (R3) | " + pct(k["rEK_mod"]) + " |")
    print("| Equity-IRR der EK-Zahlungen (R2) | " + pct(k["rEK_irr"]) + " |")
    print("| VoFi-Amortisationszeitpunkt (mit Restwert) | " + ("keine" if k["t_amort"] is None else ("%g" % k["t_amort"]).replace(".", ",")) + " |")
    print("| VoFi-Amortisationszeitpunkt (ohne Restwert) | " + ("keine im Horizont" if k["t_amort_ohneRW"] is None else ("%g" % k["t_amort_ohneRW"]).replace(".", ",")) + " |")
    print("| min. Nettoliquidität min(G_t − KK_t) | " + fmt(k["minLiq"]) + " |")
    print("| max. Kontokorrentstand | " + fmt(k["maxKK"]) + " |")
    if k["sum_nachschuss"] > 0:
        print("| Summe endogene Nachschüsse | " + fmt(k["sum_nachschuss"]) + " |")


if __name__ == "__main__":
    # ===================== Beispiel (a) =====================
    print("## Beispiel (a)\n")
    T = 5
    RW_a = 40000.0
    z_a = [-100000, 6000, 10000, 30000, 8000, 30000 + RW_a]
    mk_a = lambda: [Loan("Annuitätendarlehen", "annuity", {0: 40000}, 0.06, term=5),
                    Loan("Endfälliges Darlehen", "bullet", {0: 30000}, 0.05, term=5)]
    La = mk_a()
    ra = vofi(T, z_a, La, einlagen=[30000, 0, 0, 0, 0, 0], h=0.03, s=0.10)
    print(table(ra, La))
    tau = list(range(T + 1))
    ka = kpis(ra, tau, restwert=RW_a)
    show_kpis(ka, "(a)")
    run = lambda E: vofi(T, z_a, mk_a(), einlagen=[30000, 0, 0, 0, 0, 0],
                         entnahmen=[0] + [E] * T, h=0.03, s=0.10)
    Ea = entnahme_aequivalent(run, ka["EW_U"], T)
    print("| Entnahme-Äquivalent (VoFi-Annuität, exakt) | " + fmt(Ea) + " |")
    print("| Näherung ΔEW·h/((1+h)^T−1) | " + fmt(ka["dEW"] * 0.03 / (1.03 ** 5 - 1)) + " |")
    print("| Kapitalwert der Zahlungsfolge bei 3 % | " + fmt(npv(z_a, 0.03)) + " |")
    print("| Kapitalwert der Zahlungsfolge bei 10 % | " + fmt(npv(z_a, 0.10)) + " |")
    print("| Interner Zinsfuß der Zahlungsfolge | " + pct(irr(z_a)) + " |")
    print("| Bestandssaldo Unterlassungsalternative je t | " + "; ".join(fmt(v) for v in ka["BS_U"]) + " |")
    EWu_a, rGK_a = unlevered(T, z_a, 0.03, 0.10)
    print("| EW eigenfinanziert (EK = 100.000, keine Kredite) | " + fmt(EWu_a) + " |")
    print("| VoFi-Gesamtkapitalrendite (eigenfinanziert) | " + pct(rGK_a) + " |")
    re = run(Ea)
    print("\nKontrolle: EW bei Entnahme E* =", fmt(re["BS"][T]), "(soll = EW_U)")
    print("\nKontrolle: max|Finanzierungssaldo| = %.1e; max. Abweichung Vermögensfortschreibung = %.1e" % check(ra, La))

    # ----- (a3) Variante: Sondertilgung aus Ueberschuessen (Annuitaetendarlehen) -----
    print("\n### (a3) Variante mit Sondertilgungsregel\n")
    La3 = mk_a()
    ra3 = vofi(T, z_a, La3, einlagen=[30000, 0, 0, 0, 0, 0], h=0.03, s=0.10,
               sonder=("Annuitätendarlehen",))
    print(table(ra3, La3))
    ka3 = kpis(ra3, tau, restwert=RW_a)
    show_kpis(ka3, "(a3)")
    print("\nKontrolle: max|Finanzierungssaldo| = %.1e; max. Abweichung Vermögensfortschreibung = %.1e" % check(ra3, La3))

    # ===================== Beispiel (d): vollkommener Kapitalmarkt =====================
    print("\n## Beispiel (d) Konsistenztest vollkommener Kapitalmarkt (alle Zinssätze 5 %)\n")
    Ld = [Loan("Annuitätendarlehen", "annuity", {0: 40000}, 0.05, term=5),
          Loan("Endfälliges Darlehen", "bullet", {0: 30000}, 0.05, term=5)]
    rd = vofi(T, z_a, Ld, einlagen=[30000, 0, 0, 0, 0, 0], h=0.05, s=0.05)
    kd = kpis(rd, tau, restwert=RW_a)
    print("| Größe | Wert |\n|---|---:|")
    print("| EW | " + fmt(kd["EW"]) + " |")
    print("| EW_U = 30.000·1,05^5 | " + fmt(kd["EW_U"]) + " |")
    print("| ΔEW | " + fmt(kd["dEW"]) + " |")
    print("| KW(5 %)·1,05^5 | " + fmt(npv(z_a, 0.05) * 1.05 ** 5) + " |")
    print("| KW(5 %) | " + fmt(npv(z_a, 0.05)) + " |")
    print("| Differenz (soll 0) | %.3e |" % (kd["dEW"] - npv(z_a, 0.05) * 1.05 ** 5))
    print("| r_EK klassisch | " + pct(kd["rEK_klass"]) + " |")
    print("\nKontrolle: max|Finanzierungssaldo| = %.1e; max. Abweichung Vermögensfortschreibung = %.1e" % check(rd, Ld))

    # ===================== Beispiel (b) =====================
    print("\n## Beispiel (b)\n")
    T = 10
    RW_b = 60000.0
    z_b = [-200000.0] + [14000.0 * 1.02 ** (t - 1) for t in range(1, T + 1)]
    z_b[T] += RW_b
    def mk_b(effect):
        return [Loan("Förderdarlehen", "installment", {0: 150000}, 0.02, term=10, grace=2,
                     tz=22500.0, tz_t=1, tz_effect=effect)]
    for effect, lab in [("shorten_term", "(b1) Tilgungszuschuss verkürzt Laufzeit"),
                        ("reduce_installment", "(b2) Tilgungszuschuss senkt Tilgungsrate")]:
        Lb = mk_b(effect)
        rb = vofi(T, z_b, Lb, einlagen=[50000] + [0] * T, h=0.02, s=0.08)
        print("\n### " + lab + "\n")
        print(table(rb, Lb))
        noi_b = [0.0] + [14000.0 * 1.02 ** (t - 1) for t in range(1, T + 1)]
        kb = kpis(rb, list(range(T + 1)), restwert=RW_b, noi=noi_b, kd_loans=["Förderdarlehen"])
        show_kpis(kb, lab)
        runb = lambda E, effect=effect: vofi(T, z_b, mk_b(effect), einlagen=[50000] + [0] * T,
                                             entnahmen=[0] + [E] * T, h=0.02, s=0.08)
        print("| Entnahme-Äquivalent (exakt) | " + fmt(entnahme_aequivalent(runb, kb["EW_U"], T)) + " |")
        print("| DSCR_t (t=1..10) | " + "; ".join(fmt(v) if v is not None else "n. d." for v in kb["DSCR"][1:]) + " |")
        print("| Kapitalwert z bei 2 % | " + fmt(npv(z_b, 0.02)) + " |")
        print("| IZF z | " + pct(irr(z_b)) + " |")
        print("\nKontrolle: max|Finanzierungssaldo| = %.1e; max. Abweichung Vermögensfortschreibung = %.1e" % check(rb, Lb))

    # ===================== Beispiel (c) =====================
    print("\n## Beispiel (c)\n")
    T = 10
    V0, g, sell = 280000.0, 0.02, 0.03
    V = [V0 * (1 + g) ** t for t in range(T + 1)]
    RW_c = V[T] * (1 - sell)
    noi_c = [0.0] + [12000.0 * 1.02 ** (t - 1) for t in range(1, T + 1)]
    z_c = [-300000.0] + noi_c[1:]
    z_c[T] += RW_c
    mk_c = lambda: [Loan("Annuitätendarlehen", "annuity", {0: 300000}, 0.038, term=None, init_tilg=0.02)]
    Lc = mk_c()
    rc = vofi(T, z_c, Lc, einlagen=0.0, h=0.025, s=0.09)
    print("### (c1) Defizite über Kontokorrent (Limit unbegrenzt)\n")
    print(table(rc, Lc))
    kc = kpis(rc, list(range(T + 1)), restwert=RW_c, noi=noi_c, value=V, kd_loans=["Annuitätendarlehen"])
    show_kpis(kc, "(c1)")
    print("| DSCR_t | " + "; ".join(fmt(v) for v in kc["DSCR"][1:]) + " |")
    print("| LTV_t (inkl. KK) | " + "; ".join(pct(v, 2) for v in kc["LTV"]) + " |")
    print("| Restwert netto (V_T·0,97) | " + fmt(RW_c) + " |")
    runc = lambda E: vofi(T, z_c, mk_c(), einlagen=0.0, entnahmen=[0] + [E] * T, h=0.025, s=0.09)
    print("| Entnahme-Äquivalent (exakt) | " + fmt(entnahme_aequivalent(runc, kc["EW_U"], T)) + " |")
    # Break-even NOI_1 (EW = EW_U = 0)
    def ew_noi(n1):
        noi = [0.0] + [n1 * 1.02 ** (t - 1) for t in range(1, T + 1)]
        zz = [-300000.0] + noi[1:]
        zz[T] += RW_c
        return vofi(T, zz, mk_c(), einlagen=0.0, h=0.025, s=0.09)["BS"][T]
    be = bisect(lambda n1: ew_noi(n1), 0.0, 50000.0)
    print("| Break-even-NOI_1 (ΔEW = 0) | " + fmt(be) + " |")
    print("| Liquiditäts-Break-even-NOI_1 (DSCR_1 = 1) | " + fmt(300000 * 0.058) + " |")
    print("| Projekt-IZF der Zahlungsfolge | " + pct(irr(z_c)) + " |")
    print("| EW / Investitionsvolumen | " + pct(kc["EW"] / 300000, 2) + " |")
    EWu_c, rGK_c = unlevered(T, z_c, 0.025, 0.09)
    print("| EW eigenfinanziert (EK = 300.000) | " + fmt(EWu_c) + " |")
    print("| VoFi-Gesamtkapitalrendite (eigenfinanziert) | " + pct(rGK_c) + " |")
    print("\nKontrolle: max|Finanzierungssaldo| = %.1e; max. Abweichung Vermögensfortschreibung = %.1e" % check(rc, Lc))

    print("\n### (c2) Defizite durch Nachschuss (KK-Limit 0, policy equity_call)\n")
    Lc2 = mk_c()
    rc2 = vofi(T, z_c, Lc2, einlagen=0.0, h=0.025, s=0.09, kk_limit=0.0, policy="equity_call")
    print(table(rc2, Lc2))
    kc2 = kpis(rc2, list(range(T + 1)), restwert=RW_c, noi=noi_c, value=V, kd_loans=["Annuitätendarlehen"])
    show_kpis(kc2, "(c2)")
    print("| Barwert der Nachschüsse bei h | " + fmt(sum(rc2["nachschuss"][t] / 1.025 ** t for t in range(T + 1))) + " |")
    print("\nKontrolle: max|Finanzierungssaldo| = %.1e; max. Abweichung Vermögensfortschreibung = %.1e" % check(rc2, Lc2))

    # ===================== Beispiel (e): nicht-aequidistantes Raster =====================
    print("\n## Beispiel (e) Bauphase quartalsweise, Betriebsphase jaehrlich\n")
    dt = [0.0, .25, .25, .25, .25, 1.0, 1.0, 1.0]
    tau_e = [0.0]
    for d in dt[1:]:
        tau_e.append(tau_e[-1] + d)
    T = 7
    he = [0.0] + [(1.025) ** d - 1 for d in dt[1:]]
    se = [0.0] + [(1.09) ** d - 1 for d in dt[1:]]
    rate_e = [0.0] + [0.036 * d for d in dt[1:]]
    RW_e = 520000.0
    z_e = [-200000.0, -100000.0, -100000.0, -100000.0, 0.0, 30000.0, 30600.0, 31212.0 + RW_e]
    Le = [Loan("Baudarlehen", "annuity", {0: 100000, 1: 100000, 2: 100000, 3: 100000}, rate_e,
               term=None, grace=1, init_tilg=0.02, commit_fee=0.0075, fee_from=2)]
    re_ = vofi(T, z_e, Le, einlagen=[100000.0] + [0.0] * T, h=he, s=se)
    labels = ["0", "0,25", "0,5", "0,75", "1", "2", "3", "4"]
    print(table(re_, Le, tau_labels=labels))
    ke = kpis(re_, tau_e, restwert=RW_e)
    show_kpis(ke, "(e)")
    print("\nPeriodenzinssätze Haben (t=1..7):", "; ".join("%.10f" % x for x in he[1:]))
    print("\nPeriodenzinssätze KK (t=1..7):", "; ".join("%.10f" % x for x in se[1:]))
    print("\nKontrolle: max|Finanzierungssaldo| = %.1e; max. Abweichung Vermögensfortschreibung = %.1e" % check(re_, Le))

    # ===================== Test (f): Monatsannuitaet auf Jahresraster =====================
    print("\n## Test (f) Monatsannuitaet, aggregiert auf Jahresperiode\n")
    K, inom, n = 100000.0, 0.036, 240
    im = inom / 12
    A = K * im / (1 - (1 + im) ** (-n))
    B, zs, ts = K, 0.0, 0.0
    for m in range(12):
        zi = B * im
        ti = A - zi
        zs += zi
        ts += ti
        B -= ti
    print("| Größe | Wert |\n|---|---:|")
    print("| Monatsrate | " + fmt(A) + " |")
    print("| Zinsen Jahr 1 (Summe) | " + fmt(zs) + " |")
    print("| Tilgung Jahr 1 (Summe) | " + fmt(ts) + " |")
    print("| Restschuld Ende Jahr 1 | " + fmt(B) + " |")
    print("| Effektiver Jahreszins (1+i/12)^12−1 | " + pct((1 + im) ** 12 - 1) + " |")
