"""Build the student and teacher versions of the CFA playground + worksheet.

Run from anywhere:  python3 widgets/_src/build_cfa_playground.py

Student  -> widgets/cfa_playground.html          (answers stored only as hashes)
Teacher  -> widgets/_src/cfa_playground_teacher.html (answer key shown; not copied to the site)

Expected answers are computed here from the model definitions, using the same
term-counting rule as the widget's tracing equations.
"""
import json
from pathlib import Path

HERE = Path(__file__).parent
P, K, INFO = 6, 2, 21

def hash_of(q, row, v):
    x = 0x811c9dc5
    for ch in f"cfa8|{q}|{row}|{v}":
        x ^= ord(ch)
        x = (x * 0x01000193) & 0xFFFFFFFF
    return x

keys = [f"l{i}{j}" for i in range(1, P + 1) for j in range(1, K + 1)] + ["p21"] + \
       [f"t{i}{j}" for i in range(1, P + 1) for j in range(1, i + 1)]

def terms(i, j, F):
    """Terms of the tracing equation for cell (i, j), each as a sorted token tuple (coefficient ignored)."""
    out = []
    for k in (1, 2):
        for l in (1, 2):
            a, b = f"l{i}{k}", f"l{j}{l}"
            if not (F[a] and F[b]): continue
            if k != l and not F["p21"]: continue
            if i == j and k > l: continue
            out.append(tuple(sorted([a, b] + (["p21"] if k != l else []))))
    if F[f"t{i}{j}"]: out.append((f"t{i}{j}",))
    return out

def removed(i, j, F):
    return sorted(set(terms(i, j, ORIG)) - set(terms(i, j, F)))

def canon(ts):
    return "|".join(sorted(" ".join(t) for t in ts))

ORIG = {k: True for k in keys}
def answers(F):
    zeros = lambda pre: sum(1 for k in keys if k[0] == pre and not F[k])
    n_free = sum(F.values())
    return {
        "df": INFO - n_free, "l0": zeros("l"), "p0": zeros("p"), "t0": zeros("t"),
        "vr": canon(removed(1, 1, F)),
        "cv": canon(removed(2, 1, F)),
    }

def scenario(drop):
    return {k: not drop(k) for k in keys}

SCEN = {
    1: scenario(lambda k: k[0] == "t" and k[1] != k[2]),                        # residual covariances
    2: scenario(lambda k: k[0] == "l" and ((int(k[1]) <= 3) != (k[2] == "1"))),  # cross-loadings
    3: scenario(lambda k: k == "p21"),                                          # factor covariance
}
PLAIN = {q: answers(F) for q, F in SCEN.items()}

# hand-derived values, as a guard against drift
assert answers(ORIG) == {"df": -13, "l0": 0, "p0": 0, "t0": 0, "vr": "", "cv": ""}
assert PLAIN[1] == {"df": 2, "l0": 0, "p0": 0, "t0": 15, "vr": "", "cv": "t21"}
assert PLAIN[2] == {"df": -7, "l0": 6, "p0": 0, "t0": 0,
                    "vr": "l11 l12 p21|l12 l12", "cv": "l11 l22 p21|l12 l21 p21|l12 l22"}
assert PLAIN[3] == {"df": -12, "l0": 0, "p0": 1, "t0": 0, "vr": "l11 l12 p21", "cv": "l11 l22 p21|l12 l21 p21"}

hashes = {f"{q}|{r}": hash_of(q, r, v) for q, d in PLAIN.items() for r, v in d.items()}

ROWS = [("df", "Degrees of freedom"), ("l0", "0s in &Lambda;"), ("p0", "0s in &Psi;"), ("t0", "0s in &Theta;"),
        ("vr", "Terms removed, Var(PARENTED)"), ("cv", "Terms removed, Cov(PARENTED, BOOKSHOME)")]
QN = {1: "Q1. No residual covariances", 2: "Q2. No cross-loadings", 3: "Q3. No factor covariance"}

import re
def pretty(c, var=False):
    if c == "": return "none"
    out = []
    for t in c.split("|"):
        toks = t.split()
        sq = len(toks) == 2 and toks[0] == toks[1]
        def g(x): return {"l": "&lambda;", "p": "&psi;", "t": "&theta;"}[x[0]] + x[1:]
        if len(toks) == 3:
            toks = [x for x in toks if x[0] == "l"][:1] + ["p21"] + [x for x in toks if x[0] == "l"][1:]
        out.append(g(toks[0]) + "<sup>2</sup>" if sq else ("2" if var and len(toks) == 3 else "") + "".join(g(x) for x in toks))
    return ", ".join(out)

def key_html():
    head = "".join(f"<th>{QN[q]}</th>" for q in QN)
    body = "".join(f"<tr><th class='rowh'>{lab}</th>" + "".join(f"<td>{pretty(PLAIN[q][r], r == 'vr') if r in ('vr','cv') else PLAIN[q][r]}</td>" for q in QN) + "</tr>" for r, lab in ROWS)
    return f"""
<div class="card" id="c-key">
  <h2>Teacher answer key</h2>
  <table class="m"><tr><th></th>{head}</tr>{body}</table>
  <p class="note">Path answers are accepted in any order, with or without the coefficient 2, and typed as l11 l21, psi21, theta21 or with Greek letters. Q4 (written explanation) and the Part 2 challenge are not auto-checked.</p>
  <p class="note"><b>Challenge reference.</b> Cross-loadings and residual covariances fixed to 0 (13 free, df = 8), ML estimates (listwise N = 3,767):
  &lambda;<sub>11</sub> .335, &lambda;<sub>21</sub> .824, &lambda;<sub>31</sub> .089, &lambda;<sub>42</sub> .935, &lambda;<sub>52</sub> .949, &lambda;<sub>62</sub> .980, &psi;<sub>21</sub> .536,
  &theta;<sub>11</sub> .887, &theta;<sub>22</sub> .321, &theta;<sub>33</sub> .992, &theta;<sub>44</sub> .126, &theta;<sub>55</sub> .099, &theta;<sub>66</sub> .039; SRMR &approx; .027.
  Any estimates close to these pass. Fixing &psi;<sub>21</sub> to 0 gives SRMR &approx; .18. Tip: <code>?preset=cfa</code> opens that model.</p>
</div>"""

tpl = (HERE / "cfa_playground.template.html").read_text()
assert "/*HASHES*/{}" in tpl

def build(teacher):
    out = tpl.replace("/*HASHES*/{}", json.dumps(hashes))
    out = out.replace("/*TEACHERBANNER*/", '<div class="teacherbanner">TEACHER VERSION: answer key at the bottom. Do not post.</div>' if teacher else "")
    out = out.replace("/*TEACHERKEY*/", key_html() if teacher else "")
    return out

(HERE.parent / "cfa_playground.html").write_text(build(False))
(HERE / "cfa_playground_teacher.html").write_text(build(True))
print("ok", PLAIN)
