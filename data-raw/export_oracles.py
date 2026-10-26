#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Export der Testorakel (Spec 00 Abschnitt 15.3, Memo 01 Abschnitt 10; Arbeitspaket WS-T).

Ruft die unveraenderten Funktionen aus data-raw/vofi_ref.py (Kopie von
docs/recherche/prototypen/vofi_referenz/vofi_ref.py) auf und schreibt je Orakel <id>

  tests/testthat/fixtures/oracles/<id>_rows.csv   row_key,t,value            (Orakel (g): + variant)
  tests/testthat/fixtures/oracles/<id>_kpis.csv   kpi,value,na_reason        (Orakel (g): + variant)
  tests/testthat/fixtures/oracles/c1_solve.csv    what,param,kpi,target,value (Zielwertsuche, 12.8)

Werte ungerundet mit "%.15g" (Spec 00 15.3 nennt "%.12g"; bei Betraegen ab 1e5 laege der
Formatfehler mit 12 Stellen an der Orakeltoleranz 1e-6, daher 15 Stellen); NA-Kennzahlen mit
leerem Wert und Begruendungscode
(Spec 00 12.4). Die Szenarien der Orakel stehen von Hand modelliert in
tests/testthat/fixtures/oracles/<id>.yaml; test-oracles.R prueft, dass Referenz-Engine und Paket
aus diesen Szenarien die hier exportierten Werte reproduzieren.

Erweiterungen gegenueber vofi_ref.py (nur in dieser Datei, vofi_ref.py bleibt unveraendert):
  * MonthlyLoan: Monatsuhr nach Spec 00 8.5 fuer die Orakel (f) (Monatsannuitaet) und
    (h) (Ratendarlehen mit Zinsanpassung, Spec 00 8.10) mit derselben Schnittstelle wie
    vofi_ref.Loan, sodass vofi_ref.vofi() unveraendert die Konten fuehrt;
  * Kennzahlen nach Spec 00 12.3 (inkl. Sicht ohne Restwert 9.4, Vermoegensamortisation,
    Entnahme-Aequivalent 12.8 mit Nachschusskorrektur, DSCR/ICR/LTV, IZF der Zahlungsfolge);
  * Orakel (g) (Vergleichsregel, Spec 00 9.6 Nr. 4, R-66): zwei Varianten mit ungleichen
    Nachschuessen, delta_vs_reference = dEW_A - dEW_ref;
  * Zielwertsuche (Spec 00 12.8, R-75): Break-even-NOI_1 von (c1) (dEW = 0 ueber den
    Anfangswert der NOI-Reihe, Pfad components.noi.amount_eur) per Bisektion wie im Hauptteil
    von vofi_ref.py.

Aufruf (aus der Paketwurzel):  python3 data-raw/export_oracles.py
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import vofi_ref as V  # noqa: E402  (unveraenderte Referenzimplementierung)

INF = V.INF
EPS = V.EPS
ZERO_ABS = 1e-9          # vofi_tol$zero_abs (Spec 00 2.13)
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "tests", "testthat", "fixtures", "oracles"))


# ------------------------------------------------------------------------------------------------
# Raster (Spec 00 Abschnitt 3): Periodenlaengen in Monaten, Zeit in Jahren, Kalenderjahr des
# Periodenbeginns, Betriebsjahre (Stichtag 2027-01-01)
# ------------------------------------------------------------------------------------------------
class Grid:
    def __init__(self, months, construction_months=0, start_year=2027):
        self.months = list(months)
        self.T = len(months) - 1
        self.delta = [m / 12.0 for m in months]
        self.tau, self.month_end = [0.0], [0]
        for t in range(1, self.T + 1):
            self.tau.append(self.tau[-1] + self.delta[t])
            self.month_end.append(self.month_end[-1] + months[t])
        # Kalenderjahr des Periodenbeginns (Monatsindex ab Stichtag 2027-01-01)
        self.year = [start_year] + [start_year + self.month_end[t - 1] // 12
                                    for t in range(1, self.T + 1)]
        self.phase = ["construction" if construction_months > 0 else "operation"]
        for t in range(1, self.T + 1):
            self.phase.append("construction" if self.month_end[t - 1] < construction_months
                              else "operation")
        # Betriebsjahre auf kalenderjahrbuendigen Rastern (Spec 00 3.3, calendar)
        first_op = None
        self.op_year = [0]
        for t in range(1, self.T + 1):
            if self.phase[t] == "operation":
                if first_op is None:
                    first_op = self.year[t]
                self.op_year.append(self.year[t] - first_op + 1)
            else:
                self.op_year.append(0)


def annual_grid(T):
    return Grid([0] + [12] * T)


# ------------------------------------------------------------------------------------------------
# Erweiterung: Monatsuhr (Spec 00 8.5) fuer Orakel (f) und (h)
# ------------------------------------------------------------------------------------------------
class MonthlyLoan:
    """Darlehen mit Monatsuhr: Zinsen i/12 auf den Monatsanfangsbestand, Raten in
    Vertragsfrequenz ppy, eine Auszahlung in t = 0 (keine tilgungsfreie Zeit, keine Gebuehren,
    kein Tilgungszuschuss), optional eine Zinsanpassung nach reset_month Monaten mit keep_term
    (Spec 00 8.6). Gleiche Schnittstelle wie vofi_ref.Loan (reset, step, name, B, disb, rate)."""

    def __init__(self, name, kind, amount, rate_pa, grid, term_months, ppy=12,
                 reset_month=None, followup_pa=None):
        assert kind in ("annuity", "installment")
        self.name, self.kind = name, kind
        self.disb = {0: float(amount)}
        self.commitment = float(amount)
        self.rate_pa, self.grid = float(rate_pa), grid
        self.term, self.ppy, self.pi = term_months, ppy, 12 // ppy
        self.reset_month, self.followup = reset_month, followup_pa

    def reset(self, T):
        self.B, self.i, self.inst, self.accrued = 0.0, self.rate_pa, None, 0.0
        self.rate = [0.0] + [self.rate_pa * self.grid.delta[t] for t in range(1, T + 1)]

    def n_rem(self, m):
        return sum(1 for k in range(m + 1, self.term + 1) if k % self.pi == 0)

    def _installment(self, basis, i_pa, n):
        if self.kind == "installment":
            return basis / n
        i_s = i_pa / self.ppy
        return basis / n if i_s == 0 else basis * i_s / (1 - (1 + i_s) ** (-n))

    def step(self, t):
        zins = tilg = 0.0
        if t > 0:
            for m in range(self.grid.month_end[t - 1] + 1, self.grid.month_end[t] + 1):
                if self.reset_month is not None and m - 1 == self.reset_month:
                    self.i = self.followup                       # (a) Zinsanpassung, keep_term
                    if self.inst is not None:
                        self.inst = self._installment(self.B, self.i, self.n_rem(m - 1))
                z = self.B * self.i / 12.0                        # (c) Monatszins
                zins += z
                self.accrued += z
                if m % self.pi == 0 and m <= self.term:           # (e) Vertragszahlung
                    if self.inst is None:
                        self.inst = self._installment(self.commitment, self.i,
                                                      self.term // self.pi)
                    if self.kind == "annuity":
                        r = min(max(self.inst - self.accrued, 0.0), self.B)
                    else:
                        r = min(self.inst, self.B)
                    self.B -= r
                    tilg += r
                    self.accrued = 0.0
                if m == self.term:                                # (f) Schlusstilgung
                    tilg += self.B
                    self.B = 0.0
        d = self.disb.get(t, 0.0)                                 # (h) Auszahlung am Periodenende
        self.B += d
        return d, zins, 0.0, tilg, 0.0


# ------------------------------------------------------------------------------------------------
# Kennzahlen nach Spec 00 Abschnitt 12 (Erweiterung)
# ------------------------------------------------------------------------------------------------
def acc_factors(h):
    q = [1.0]
    for t in range(1, len(h)):
        q.append(q[-1] * (1 + h[t]))
    return q


def terminal_ex_rv(res, loans, rw, kk_limit, sonder):
    """Terminalzustand ohne Restwert (Spec 00 9.4): Ausgleich der Periode T mit
    S' = S_T - RW_T + NS_T ab dem Stand vor dem Ausgleich; D4 mit Zufluss von aussen wird nicht
    ausgefuehrt, der Rest geht in die Strafzinstranche (gap)."""
    T, h = res["_T"], res["_h"]
    S2 = res["S_vor"][T] - rw + res["nachschuss"][T]
    G0, KK0 = (res["G"][T - 1], res["KK"][T - 1]) if T > 0 else (0.0, 0.0)
    B = {L.name: res[L.name + "_B"][T] - res[L.name + "_st"][T] for L in loans}
    anlage = aufl = kk_auf = kk_tilg = gap = 0.0
    if S2 >= 0:
        kk_tilg = min(S2, KK0)
        rest = S2 - kk_tilg
        for L in sorted([L for L in loans if L.name in sonder], key=lambda L: -L.rate[T]):
            if rest <= EPS or T == 0 or L.rate[T] <= h[T]:
                continue
            a = min(rest, B[L.name])
            B[L.name] -= a
            rest -= a
        anlage = rest
    else:
        need = -S2
        aufl = min(need, G0)
        need -= aufl
        kk_auf = min(need, max(kk_limit - KK0, 0.0))
        need -= kk_auf
        gap = max(need, 0.0)
    G = G0 + anlage - aufl
    KK = KK0 + kk_auf - kk_tilg
    BS = G - KK - gap - sum(B.values())
    return {"G": G, "KK": KK, "KKP": gap, "BS": BS, "gap": gap}


def sign_changes(cf):
    s = [1 if c > 0 else -1 for c in cf if abs(c) > ZERO_ABS]
    return sum(1 for a, b in zip(s, s[1:]) if a != b)


def irr_code(cf, tau):
    """IZF mit Bisektion auf [-0.99, 1] (Spec 00 12.3) -> (Wert, NA-Code)."""
    if sign_changes(cf) > 1:
        return None, "irr_ambiguous"
    r = V.irr(cf, tau, lo=-0.99, hi=1.0)
    if r is None:
        return None, "irr_out_of_range"
    return r, None


def roe_set(EW, EL, EN, q, TJ, tau):
    """roe_classic, roe_mirr, roe_irr mit NA-Codes (Spec 00 12.3)."""
    T = len(EL) - 1
    out = {}
    # R1 klassisch
    if EL[0] <= ZERO_ABS:
        out["roe_classic"] = (None, "no_equity")
    elif any(abs(EL[t]) > ZERO_ABS for t in range(1, T + 1)) or any(abs(e) > ZERO_ABS for e in EN):
        out["roe_classic"] = (None, "multiple_equity_flows")
    elif EW <= 0:
        out["roe_classic"] = (None, "equity_lost")
    else:
        out["roe_classic"] = ((EW / EL[0]) ** (1.0 / TJ) - 1, None)
    # R3 modifiziert
    num = EW + sum(EN[t] * q[T] / q[t] for t in range(T + 1))
    den = sum(EL[t] / q[t] for t in range(T + 1))
    if den <= ZERO_ABS:
        out["roe_mirr"] = (None, "no_equity")
        out["roe_irr"] = (None, "no_equity")
    elif num <= 0:
        out["roe_mirr"] = (None, "equity_lost")
        out["roe_irr"] = (None, "equity_lost")
    else:
        out["roe_mirr"] = ((num / den) ** (1.0 / TJ) - 1, None)
        cf = [-EL[t] + EN[t] for t in range(T + 1)]
        cf[T] += EW
        out["roe_irr"] = irr_code(cf, tau)
    return out


def payback(bs, bs_u, tau, year):
    """Vermoegensamortisation (Spec 00 12.3, R-72): t* = min{t : d_u >= -tol_u fuer u >= t}."""
    T = len(bs) - 1
    tstar = None
    for t in range(T, -1, -1):
        if bs[t] - bs_u[t] >= -1e-9 * max(1.0, abs(bs_u[t])):
            tstar = t
        else:
            break
    if tstar is None:
        return (None, "no_payback"), (None, "no_payback")
    return (tau[tstar], None), (year[tstar], None)


def withdrawal_equivalent(rerun, nach0, q, EW_U, dEW, TJ, ex_rv=None, tol=1e-11):
    """Entnahme-Aequivalent (Spec 00 12.8): f(E) = BS(E) - sum dNS(E) q_T/q_t - EW_U."""
    T = len(q) - 1

    def f(E):
        res, loans = rerun(E)
        bs = res["BS"][T] if ex_rv is None else ex_rv(res, loans)["BS"]
        dns = sum((res["nachschuss"][t] - nach0[t]) * q[T] / q[t] for t in range(T + 1))
        return bs - dns - EW_U

    lo, hi = min(dEW, 0.0) / TJ - 1.0, max(dEW, 0.0) / TJ + 1.0
    for _ in range(30):
        if f(lo) >= 0 and f(hi) <= 0:
            break
        lo, hi = 2 * lo, 2 * hi
    else:
        return None, "no_solution"
    flo = f(lo)
    for _ in range(400):
        mid = 0.5 * (lo + hi)
        fm = f(mid)
        if (fm > 0) == (flo > 0):
            lo, flo = mid, fm
        else:
            hi = mid
        if hi - lo < tol:
            break
    return 0.5 * (lo + hi), None


def op_year_sums(grid, x):
    years = sorted(set(y for y in grid.op_year if y > 0))
    return years, [sum(x[t] for t in range(grid.T + 1) if grid.op_year[t] == y) for y in years]


def spec_kpis(case, res, loans):
    """Kennzahlen eines Orakellaufs nach Spec 00 12.3 (mit und ohne Restwert)."""
    g = case["grid"]
    T, tau, year = g.T, g.tau, g.year
    TJ = tau[T]
    h, rw = res["_h"], case["rw"]
    q = acc_factors(h)
    memo = V.kpis(res, tau, restwert=rw)                 # EW, EW_U, BS^U (unveraendert)
    EW, EW_U, BS_U = memo["EW"], memo["EW_U"], memo["BS_U"]
    nach = res["nachschuss"]
    EL = [res["einl"][t] + nach[t] for t in range(T + 1)]
    EN = list(res["_entn"])
    ex = terminal_ex_rv(res, loans, rw, case["kk_limit"], case["sonder"])
    out = {}

    def put(name, val):
        out[name] = val if isinstance(val, tuple) else (val, None)

    put("terminal_value", EW)
    put("terminal_value_ex_rv", ex["BS"])
    put("terminal_value_opp", EW_U)
    put("delta_terminal_value", EW - EW_U)
    put("delta_terminal_value_ex_rv", ex["BS"] - EW_U)
    for suffix, ew in (("", EW), ("_ex_rv", ex["BS"])):
        for k, v in roe_set(ew, EL, EN, q, TJ, tau).items():
            put(k + suffix, v)
    bs = list(res["BS"])
    bs_ex = bs[:-1] + [ex["BS"]]
    for suffix, b in (("", bs), ("_ex_rv", bs_ex)):
        pt, py = payback(b, BS_U, tau, year)
        put("payback_time" + suffix, pt)
        put("payback_year" + suffix, py)
    G, KK = list(res["G"]), list(res["KK"])
    KKP = [0.0] * (T + 1)
    G_ex, KK_ex, KKP_ex = G[:-1] + [ex["G"]], KK[:-1] + [ex["KK"]], KKP[:-1] + [ex["KKP"]]
    cum_ns = []
    for t in range(T + 1):
        cum_ns.append((cum_ns[-1] if t else 0.0) + nach[t])
    for suffix, (gg, kk, kp) in (("", (G, KK, KKP)), ("_ex_rv", (G_ex, KK_ex, KKP_ex))):
        put("min_net_liquidity" + suffix, min(gg[t] - kk[t] - kp[t] for t in range(T + 1)))
        put("max_overdraft" + suffix, max(kk[t] + kp[t] for t in range(T + 1)))
        put("max_financing_need" + suffix, max(kk[t] + kp[t] + cum_ns[t] for t in range(T + 1)))
    put("sum_equity_calls", sum(nach))
    put("pv_equity_calls", sum(nach[t] / q[t] for t in range(T + 1)))
    put("flag_shortfall", 1.0 if any(n > ZERO_ABS for n in nach) else 0.0)
    put("flag_limit_breach", 0.0)
    put("flag_reserve_used", 0.0)
    rerun = case["rerun"]
    put("withdrawal_equivalent",
        withdrawal_equivalent(rerun, nach, q, EW_U, EW - EW_U, TJ))
    put("withdrawal_equivalent_ex_rv",
        withdrawal_equivalent(rerun, nach, q, EW_U, ex["BS"] - EW_U, TJ,
                              ex_rv=lambda r, L: terminal_ex_rv(r, L, rw, case["kk_limit"],
                                                                case["sonder"])))
    cf = [res["z"][t] + res["zus"][t] for t in range(T + 1)]
    put("npv_cf_project", sum(cf[t] / q[t] for t in range(T + 1)))
    put("irr_cf_project", irr_code(cf, tau))
    if case.get("noi") is not None:
        noi = case["noi"]
        kd = [sum(-(res[n + "_zins"][t] + res[n + "_tilg"][t]) for n in case["kd_loans"])
              for t in range(T + 1)]
        it = [sum(-res[n + "_zins"][t] for n in case["kd_loans"]) for t in range(T + 1)]
        years, noi_y = op_year_sums(g, noi)
        _, kd_y = op_year_sums(g, kd)
        _, int_y = op_year_sums(g, it)
        dscr = [n / k for n, k in zip(noi_y, kd_y) if k > ZERO_ABS]
        icr = [n / k for n, k in zip(noi_y, int_y) if k > ZERO_ABS]
        if dscr:
            put("dscr_min", min(dscr))
            put("dscr_mean", sum(dscr) / len(dscr))
            put("dscr_years_below", float(sum(1 for d in dscr if d < case["dscr_threshold"])))
            put("dscr_min_new", min(dscr))
        else:
            for k in ("dscr_min", "dscr_mean", "dscr_years_below", "dscr_min_new"):
                put(k, (None, "no_debt_service"))
        put("icr_min", min(icr) if icr else (None, "no_debt_service"))
    if case.get("value") is not None:
        Vt = case["value"]
        debt = [sum(res[L.name + "_B"][t] for L in loans) for t in range(T + 1)]
        ltv = [(debt[t] + KK[t] + KKP[t]) / Vt[t] for t in range(T + 1) if Vt[t] > ZERO_ABS]
        put("ltv_max", max(ltv))
        put("ltv_end", (debt[T] + KK[T] + KKP[T]) / Vt[T])
        put("lending_ratio_max", max(debt[t] / (Vt[t] * (1 - case["haircut"]))
                                     for t in range(T + 1) if Vt[t] > ZERO_ABS))
    return out, memo, ex


# ------------------------------------------------------------------------------------------------
# Orakel (Eingaben wie im Hauptteil von vofi_ref.py bzw. Spec 00 15.3)
# ------------------------------------------------------------------------------------------------
def make_case(grid, z, mk_loans, einl, h, s, rw, kk_limit=INF, policy="unlimited", sonder=(),
              **extra):
    T = grid.T

    def run(E):
        L = mk_loans()
        entn = [0.0] + [E * grid.delta[t] for t in range(1, T + 1)]
        return V.vofi(T, z, L, einlagen=einl, entnahmen=entn, h=h, s=s, kk_limit=kk_limit,
                      policy=policy, sonder=sonder), L

    case = dict(grid=grid, z=z, mk=mk_loans, einl=einl, h=h, s=s, rw=rw, kk_limit=kk_limit,
                policy=policy, sonder=sonder, rerun=run)
    case.update(extra)
    return case


def MK_C():
    """Kredit von (c): Annuitaet 300.000 zu 3,8 % mit anfaenglicher Tilgung 2 %."""
    return [V.Loan("ann", "annuity", {0: 300000}, 0.038, term=None, init_tilg=0.02)]


def c1_delta_ew(n1):
    """dEW von (c1) bei Anfangs-NOI n1 (NOI_t = n1 * 1,02^(t-1), Restwert V_10 * 0,97)."""
    T = 10
    rw = 280000.0 * 1.02 ** T * (1 - 0.03)
    z = [-300000.0] + [n1 * 1.02 ** (t - 1) for t in range(1, T + 1)]
    z[T] += rw
    res = V.vofi(T, z, MK_C(), einlagen=0.0, h=0.025, s=0.09)
    memo = V.kpis(res, list(range(T + 1)), restwert=rw)
    return memo["EW"] - memo["EW_U"]


def solve_lines():
    """Zielwertsuche (Spec 00 12.8): Break-even-NOI_1 von (c1), Pruefwert 9.869,14."""
    be = V.bisect(c1_delta_ew, 0.0, 50000.0)
    assert abs(c1_delta_ew(be)) < 1e-6, "Break-even (c1) nicht getroffen"
    return [["breakeven", "components.noi.amount_eur", "delta_terminal_value", "0", fmt(be)]]


def cases():
    C = {}
    # ----- (a) Lehrbuch-VoFi -------------------------------------------------------------------
    g5 = annual_grid(5)
    z_a = [-100000.0, 6000.0, 10000.0, 30000.0, 8000.0, 30000.0 + 40000.0]
    mk_a = lambda: [V.Loan("ann", "annuity", {0: 40000}, 0.06, term=5),
                    V.Loan("bul", "bullet", {0: 30000}, 0.05, term=5)]
    ek_a = [30000.0, 0, 0, 0, 0, 0]
    C["a"] = make_case(g5, z_a, mk_a, ek_a, 0.03, 0.10, 40000.0)
    C["a3"] = make_case(g5, z_a, mk_a, ek_a, 0.03, 0.10, 40000.0, sonder=("ann",))
    C["a_unlevered"] = make_case(g5, z_a, lambda: [], [100000.0, 0, 0, 0, 0, 0], 0.03, 0.10,
                                 40000.0)
    # ----- (d) vollkommener Kapitalmarkt (alle Zinsen 5 %) ---------------------------------------
    mk_d = lambda: [V.Loan("ann", "annuity", {0: 40000}, 0.05, term=5),
                    V.Loan("bul", "bullet", {0: 30000}, 0.05, term=5)]
    C["d"] = make_case(g5, z_a, mk_d, ek_a, 0.05, 0.05, 40000.0)
    # ----- (b) Ratentilgung, tilgungsfreie Jahre, Tilgungszuschuss ------------------------------
    g10 = annual_grid(10)
    noi_b = [0.0] + [14000.0 * 1.02 ** (t - 1) for t in range(1, 11)]
    z_b = [-200000.0] + noi_b[1:]
    z_b[10] += 60000.0
    for cid, eff in (("b1", "shorten_term"), ("b2", "reduce_installment")):
        mk_b = (lambda eff=eff: [V.Loan("foe", "installment", {0: 150000}, 0.02, term=10,
                                        grace=2, tz=22500.0, tz_t=1, tz_effect=eff)])
        C[cid] = make_case(g10, z_b, mk_b, [50000.0] + [0.0] * 10, 0.02, 0.08, 60000.0,
                           noi=noi_b, kd_loans=["foe"], dscr_threshold=1.2)
    # ----- (c) 100 % Fremdfinanzierung --------------------------------------------------------
    Vc = [280000.0 * 1.02 ** t for t in range(11)]
    rw_c = Vc[10] * (1 - 0.03)
    noi_c = [0.0] + [12000.0 * 1.02 ** (t - 1) for t in range(1, 11)]
    z_c = [-300000.0] + noi_c[1:]
    z_c[10] += rw_c
    mk_c = MK_C
    common_c = dict(noi=noi_c, kd_loans=["ann"], dscr_threshold=1.2, value=Vc, haircut=0.2)
    C["c1"] = make_case(g10, z_c, mk_c, 0.0, 0.025, 0.09, rw_c, **common_c)
    C["c2"] = make_case(g10, z_c, mk_c, 0.0, 0.025, 0.09, rw_c, kk_limit=0.0,
                        policy="equity_call", **common_c)
    C["c1_unlevered"] = make_case(g10, z_c, lambda: [], [300000.0] + [0.0] * 10, 0.025, 0.09,
                                  rw_c)
    # ----- (e) Bauphase quartalsweise, Betrieb jaehrlich ----------------------------------------
    ge = Grid([0, 3, 3, 3, 3, 12, 12, 12], construction_months=12)
    he = [0.0] + [1.025 ** d - 1 for d in ge.delta[1:]]
    se = [0.0] + [1.09 ** d - 1 for d in ge.delta[1:]]
    rate_e = [0.0] + [0.036 * d for d in ge.delta[1:]]
    z_e = [-200000.0, -100000.0, -100000.0, -100000.0, 0.0, 30000.0, 30600.0, 31212.0 + 520000.0]
    mk_e = lambda: [V.Loan("bau", "annuity", {0: 100000, 1: 100000, 2: 100000, 3: 100000},
                           rate_e, term=None, grace=1, init_tilg=0.02, commit_fee=0.0075,
                           fee_from=2)]
    C["e"] = make_case(ge, z_e, mk_e, [100000.0] + [0.0] * 7, he, se, 520000.0)
    # ----- (f) Monatsannuitaet 100.000, 3,6 %, 240 Monate (Spec 00 8.10) als vollstaendiger VoFi
    g20 = annual_grid(20)
    mk_f = lambda: [MonthlyLoan("ann", "annuity", 100000.0, 0.036, g20, term_months=240, ppy=12)]
    C["f"] = make_case(g20, [-120000.0] + [8000.0] * 20, mk_f, [20000.0] + [0.0] * 20, 0.02,
                       0.08, 0.0)
    # ----- (h) Ratendarlehen 120.000, 2 %, 10 J., Bindung 5 J., Anschluss 4 % (Spec 00 8.10) ---
    mk_h = lambda: [MonthlyLoan("rat", "installment", 120000.0, 0.02, g10, term_months=120,
                                ppy=12, reset_month=60, followup_pa=0.04)]
    C["h"] = make_case(g10, [-150000.0] + [15500.0] * 10, mk_h, [30000.0] + [0.0] * 10, 0.02,
                       0.06, 0.0)
    # ----- (g) Vergleichsregel: Referenz base und Variante a mit Nachschuss -------------------
    g2 = annual_grid(2)
    C["g"] = {
        "base": make_case(g2, [-10000.0, 1000.0, 12000.0], lambda: [], [10000.0, 0.0, 0.0],
                          0.02, 0.08, 0.0, kk_limit=0.0, policy="equity_call"),
        "a": make_case(g2, [-10000.0, -3000.0, 16000.0], lambda: [], [10000.0, 0.0, 0.0],
                       0.02, 0.08, 0.0, kk_limit=0.0, policy="equity_call"),
    }
    return C


# ------------------------------------------------------------------------------------------------
# Zeilen nach der Orakelabbildung (Spec 00 15.3, oracle_view())
# ------------------------------------------------------------------------------------------------
def rows_of(res, loans, memo):
    T = res["_T"]
    out = [("cf_project", res["z"]), ("grant_cash", res["zus"]), ("equity_in", res["einl"]),
           ("equity_call", res["nachschuss"]), ("equity_out", res["entn"])]
    for L in loans:
        k = L.name
        out += [("loan_%s_draw" % k, res[k + "_auf"]),
                ("loan_%s_repay_total" % k, res[k + "_tilg"]),
                ("loan_%s_prepay" % k, res[k + "_st"]),
                ("loan_%s_interest" % k, res[k + "_zins"]),
                ("loan_%s_fees" % k, res[k + "_fee"]),
                ("loan_%s_repayment_grant" % k, res[k + "_tz"]),
                ("loan_%s_balance" % k, res[k + "_B"])]
    out += [("od_draw", res["kk_auf"]), ("od_repay", res["kk_tilg"]),
            ("od_interest", res["kk_zins"]), ("od_balance", res["KK"]),
            ("dep_invest", res["anlage"]), ("dep_withdraw", res["aufl"]),
            ("dep_interest", res["hz"]), ("dep_balance", res["G"]),
            ("tax", res["steuern"]), ("balance_check", res["saldo"]),
            ("net_position", res["BS"]), ("opp_net_position", memo["BS_U"])]
    return [(k, t, float(v[t]) + 0.0) for k, v in out for t in range(T + 1)]


def fmt(x):
    s = "%.15g" % x
    assert abs(float(s) - x) <= 1e-9 * max(1.0, abs(x)), (x, s)
    return s


def write_csv(path, header, lines):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(",".join(header) + "\n")
        for ln in lines:
            f.write(",".join(ln) + "\n")


def kpi_lines(kp, variant=None):
    out = []
    for k in sorted(kp):
        v, code = kp[k]
        ln = [k, "" if v is None else fmt(v), code or ""]
        if variant is not None:
            ln.append(variant)
        out.append(ln)
    return out


def run_case(case):
    res, loans = case["rerun"](0.0)
    e1, e2 = V.check(res, loans)
    assert e1 < 1e-8 and e2 < 1e-8, ("Invariante verletzt", e1, e2)
    kp, memo, ex = spec_kpis(case, res, loans)
    assert abs(ex["BS"] - (res["BS"][res["_T"]] - case["rw"])) < 1e-8, "N2 verletzt"
    return res, loans, kp, memo


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    C = cases()
    summary = []
    for cid in sorted(C):
        if cid == "g":
            continue
        res, loans, kp, memo = run_case(C[cid])
        write_csv(os.path.join(OUT_DIR, cid + "_rows.csv"), ["row_key", "t", "value"],
                  [[k, str(t), fmt(v)] for k, t, v in rows_of(res, loans, memo)])
        write_csv(os.path.join(OUT_DIR, cid + "_kpis.csv"), ["kpi", "value", "na_reason"],
                  kpi_lines(kp))
        summary.append((cid, kp["terminal_value"][0], kp["delta_terminal_value"][0]))
    # (g): je Variante ein VoFi, Vergleichsregel dEW_A - dEW_ref (Spec 00 9.6 Nr. 4)
    rows, kls, kp_g = [], [], {}
    for var in ("base", "a"):
        res, loans, kp, memo = run_case(C["g"][var])
        kp_g[var] = kp
        rows += [[k, str(t), fmt(v), var] for k, t, v in rows_of(res, loans, memo)]
    for suffix in ("", "_ex_rv"):
        d = (kp_g["a"]["delta_terminal_value" + suffix][0] -
             kp_g["base"]["delta_terminal_value" + suffix][0])
        kp_g["a"]["delta_vs_reference" + suffix] = (d, None)
    kp_g["a"]["prob_better_than_ref"] = (1.0 if kp_g["a"]["delta_vs_reference"][0] > 0 else 0.0,
                                         None)
    for var in ("base", "a"):
        kls += kpi_lines(kp_g[var], var)
    write_csv(os.path.join(OUT_DIR, "g_rows.csv"), ["row_key", "t", "value", "variant"], rows)
    write_csv(os.path.join(OUT_DIR, "g_kpis.csv"), ["kpi", "value", "na_reason", "variant"], kls)
    summary.append(("g", kp_g["a"]["terminal_value"][0], kp_g["a"]["delta_vs_reference"][0]))
    write_csv(os.path.join(OUT_DIR, "c1_solve.csv"), ["what", "param", "kpi", "target", "value"],
              solve_lines())
    for cid, ew, d in summary:
        print("%-14s EW = %14.2f   dEW (g: delta_vs_reference) = %12.2f" % (cid, ew, d))


if __name__ == "__main__":
    main()
