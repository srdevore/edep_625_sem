"""Build the student and teacher versions of the LVPA playground + worksheet.

Run from anywhere:  python3 widgets/_src/build_lvpa_playground.py
(run `Rscript widgets/_src/fit_lvpa_widget.R` first if lvpa_fit.json is missing or the data changed)

Student  -> widgets/lvpa_playground.html            (answers stored only as hashes)
Teacher  -> widgets/_src/lvpa_playground_teacher.html (answer key shown; not copied to the site)

Expected answers are computed here from the model definitions.
Model: indicators 1-4 gm, 5-14 Stress, 15-20 Anx, 21 math (single indicator).
Original = every possible parameter free: 57 loadings (17 own + 40 cross; markers fixed),
4 structural paths (B), 4 factor/disturbance variances (Psi), 20 residual variances +
210 residual covariances (Theta; includes MATH_AVE with each item). Information = 21*22/2 = 231.
"""
import json
from pathlib import Path

HERE = Path(__file__).parent
P, INFO = 21, 231
own = lambda i: 1 if i <= 4 else 2 if i <= 14 else 3 if i <= 20 else 4
MARK = {1, 5, 15, 21}

def hash_of(q, row, v):
    x = 0x811c9dc5
    for ch in f"lvpa12|{q}|{row}|{v}":
        x ^= ord(ch)
        x = (x * 0x01000193) & 0xFFFFFFFF
    return x

BPATHS = [(2, 1), (3, 1), (3, 2), (4, 3)]
lam_keys = [("l", i, f) for i in range(1, 21) for f in (1, 2, 3) if not (f == own(i) and i in MARK)]
cross_keys = [k for k in lam_keys if k[2] != own(k[1])]
b_keys = [("b", r, c) for r, c in BPATHS]
t_keys = [("t", i, j) for i in range(2, 22) for j in range(1, i)]
KEYS = lam_keys + b_keys + t_keys
assert (len(lam_keys), len(cross_keys), len(b_keys), len(t_keys)) == (57, 40, 4, 210)
N_PSI, N_TDIAG = 4, 20

def n_free(F):
    return sum(F[k] for k in KEYS) + N_PSI + N_TDIAG

def scenario(drop):
    return {k: not drop(k) for k in KEYS}

ORIG = scenario(lambda k: False)
SCEN = {
    1: scenario(lambda k: k[0] == "t"),                        # no residual covariances
    2: scenario(lambda k: k in cross_keys),                    # no cross-loadings
    3: scenario(lambda k: k == ("b", 2, 1)),                   # drop gm -> Stress
    4: scenario(lambda k: k[0] == "t" or k in cross_keys),     # logically specified
}

# ---- factor-level path tracing: Cov(a, c) = sum over common sources x of psi_xx * paths(x->a) * paths(x->c)
def paths_from(x, a, F):
    """All directed paths x -> a through free structural paths; each as a tuple of beta keys."""
    if x == a:
        return [()]
    out = []
    for (r, c) in BPATHS:
        if r == a and F[("b", r, c)]:
            out += [p + (f"b{r}{c}",) for p in paths_from(x, c, F)]
    return out

def cov_terms(a, c, F):
    ts = []
    for x in (1, 2, 3, 4):
        for pa in paths_from(x, a, F):
            for pc in paths_from(x, c, F):
                ts.append(tuple(sorted(pa + pc + (f"p{x}{x}",))))
    return ts

def removed(a, c, F):
    return sorted(set(cov_terms(a, c, ORIG)) - set(cov_terms(a, c, F)))

canon = lambda ts: "|".join(sorted(" ".join(t) for t in ts))

def answers(F):
    zeros = lambda ks: sum(1 for k in ks if not F[k])
    return {
        "df": INFO - n_free(F), "l0": zeros(lam_keys), "b0": zeros(b_keys), "t0": zeros(t_keys),
        "c12": canon(removed(1, 2, F)), "c13": canon(removed(1, 3, F)), "c23": canon(removed(2, 3, F)),
    }

PLAIN = {q: answers(F) for q, F in SCEN.items()}

# ---- guards against drift (hand-derived)
assert INFO - n_free(ORIG) == -64
assert PLAIN[1] == {"df": 146, "l0": 0, "b0": 0, "t0": 210, "c12": "", "c13": "", "c23": ""}
assert PLAIN[2] == {"df": -24, "l0": 40, "b0": 0, "t0": 0, "c12": "", "c13": "", "c23": ""}
assert PLAIN[3] == {"df": -63, "l0": 0, "b0": 1, "t0": 0, "c12": "b21 p11", "c13": "b21 b32 p11",
                    "c23": "b21 b21 b32 p11|b21 b31 p11"}
assert PLAIN[4] == {"df": 186, "l0": 40, "b0": 0, "t0": 210, "c12": "", "c13": "", "c23": ""}
# Q4 + Q3 (what the second fitted model is): df 187
F43 = dict(SCEN[4]); F43[("b", 2, 1)] = False
assert INFO - n_free(F43) == 187
# originals: Cov(gm,Stress) = b21 p11 ; Cov(gm,Anx) = b31 p11 + b32 b21 p11 ;
# Cov(Stress,Anx) = b21 b31 p11 + b32 b21^2 p11 + b32 p22
assert canon(cov_terms(1, 2, ORIG)) == "b21 p11"
assert canon(cov_terms(1, 3, ORIG)) == "b21 b32 p11|b31 p11"
assert canon(cov_terms(2, 3, ORIG)) == "b21 b21 b32 p11|b21 b31 p11|b32 p22"

hashes = {f"{q}|{r}": hash_of(q, r, v) for q, d in PLAIN.items() for r, v in d.items()}

def pretty(c):
    if c == "":
        return "none"
    def g(x):
        return ("&beta;" if x[0] == "b" else "&psi;") + f"<sub>{x[1:]}</sub>"
    out = []
    for t in c.split("|"):
        toks = t.split()
        parts, i = [], 0
        bs = sorted(x for x in toks if x[0] == "b"); ps = [x for x in toks if x[0] == "p"]
        for x in dict.fromkeys(bs):
            parts.append(g(x) + ("<sup>2</sup>" if bs.count(x) == 2 else ""))
        out.append("".join(parts) + "".join(g(x) for x in ps))
    return ", ".join(out)

def eq_orig(a, c):
    return " + ".join(pretty(canon([t])) for t in sorted(cov_terms(a, c, ORIG)))

ORIGEQ = {
    "c12": f"Cov(gm, Stress) = {eq_orig(1, 2)}",
    "c13": f"Cov(gm, Anx) = {eq_orig(1, 3)}",
    "c23": f"Cov(Stress, Anx) = {eq_orig(2, 3)}",
}

ROWS = [("df", "Degrees of freedom"), ("l0", "0s in &Lambda;"), ("b0", "0s in B"), ("t0", "0s in &Theta;"),
        ("c12", "Terms removed, Cov(gm, Stress)"), ("c13", "Terms removed, Cov(gm, Anx)"),
        ("c23", "Terms removed, Cov(Stress, Anx)")]
QN = {1: "Q1. No residual covariances", 2: "Q2. No cross-loadings", 3: "Q3. Drop gm &rarr; Stress", 4: "Q4. Logically specified model"}

def key_html(fit):
    head = "".join(f"<th>{QN[q]}</th>" for q in QN)
    body = "".join(
        f"<tr><th class='rowh'>{lab}</th>" + "".join(
            f"<td>{pretty(PLAIN[q][r]) if r.startswith('c') else PLAIN[q][r]}</td>" for q in QN) + "</tr>"
        for r, lab in ROWS)
    h, n = fit["hyp"]["fit"], fit["noGS"]["fit"]
    return f"""
<div class="card" id="c-key">
  <h2>Teacher answer key</h2>
  <table class="m"><tr><th></th>{head}</tr>{body}</table>
  <p class="note">Term answers are accepted in any order, with or without a coefficient, typed as b21 p11, b21^2, psi11 or with Greek letters. Q5 (written explanation) is not auto-checked.
  Q1 and Q2 change only the measurement model (&Lambda;, &Theta;), so the factor-level covariances do not change: that is the point of the three &quot;none&quot; rows.
  Q3 fixes &beta;<sub>21</sub> to 0, and because Anx is a collider for gm and Stress, gm and Stress then have implied covariance 0. In lavaan, dropping <code>Stress ~ gm</code> makes both exogenous and lavaan would free their covariance (df stays 186); here &psi;<sub>21</sub> stays fixed to 0, so df = 187.</p>
  <p class="note"><b>Q5 reference.</b> Hypothesis model (Q4): &chi;&sup2;({h['df']:.0f}) = {h['chisq']:,.0f}, CFI = {h['cfi']:.3f}, TLI = {h['tli']:.3f}, RMSEA = {h['rmsea']:.3f}, SRMR = {h['srmr']:.3f}.
  <b>Global fit is mixed</b>: SRMR is acceptable but CFI/TLI/RMSEA are not, so the model is not adequate as specified. <b>Measurement model</b>: look at the standardized loadings and the residual correlation matrix. The stress items split by wording: st2, st5, st6, st8 and st9 have negative loadings (the 10 items mix positively and negatively worded statements and were not reverse-coded), and the largest residual correlations are among those items (st5/st6 .28, st6/st9 .28), so one factor does not capture them. Other misfit: an5/an6 share variance beyond the factor (.24), gm1 and gm4 are weak indicators (loadings about .5 and .4; gm1/gm4 residual .18), and gm1 relates to math more negatively than the model allows (&minus;.21). 18 of 210 residual correlations exceed .10 in absolute value.
  <b>Structural model</b>: paths are all statistically significant with N = 11,037, but R&sup2; is small (Stress {fit['hyp']['r2']['stress']:.2f}, Anx {fit['hyp']['r2']['anx']:.2f}, math {fit['hyp']['r2']['math']:.2f}); a structural interpretation is only trustworthy if the measurement model is acceptable. Dropping gm &rarr; Stress (df = 187) gives &Delta;&chi;&sup2;(1) = {fit['lrt']['chisq']:.1f} and SRMR = {n['srmr']:.3f}, so the path is supported.
  Tip: <code>?preset=hyp</code> opens the logically specified model.</p>
</div>"""

fit = json.loads((HERE / "lvpa_fit.json").read_text())
tpl = (HERE / "lvpa_playground.template.html").read_text()
for tag in ("/*FIT*/{}", "/*HASHES*/{}", "/*ORIGEQ*/{}"):
    assert tag in tpl

def build(teacher):
    out = tpl.replace("/*FIT*/{}", json.dumps({
        "hyp": fit["hyp"], "noGS": fit["noGS"], "lrt": fit["lrt"], "n": fit["n"]}, separators=(",", ":")))
    out = out.replace("/*HASHES*/{}", json.dumps(hashes))
    out = out.replace("/*ORIGEQ*/{}", json.dumps(ORIGEQ))
    out = out.replace("/*TEACHERBANNER*/", '<div class="teacherbanner">TEACHER VERSION: answer key at the bottom. Do not post.</div>' if teacher else "")
    out = out.replace("/*TEACHERKEY*/", key_html(fit) if teacher else "")
    return out

(HERE.parent / "lvpa_playground.html").write_text(build(False))
(HERE / "lvpa_playground_teacher.html").write_text(build(True))
print("ok", json.dumps(PLAIN, indent=1))
print(ORIGEQ)
