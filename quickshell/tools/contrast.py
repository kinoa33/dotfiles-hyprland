#!/usr/bin/env python3
"""contrast.py tokens.json [tokens.json ...] — the readability audit.

Each file is one tokdump run (one palette). Glass is translucent over an
unknown wallpaper, so every layer is composited over a dark AND a light
backdrop and the worse result counts — the same rule Theme.readable()
solves for. Prints a table of the worst value per theme across all the
files, flagging anything under its WCAG minimum, then the failures.
Exit status: 1 if anything fails.
"""
import json
import os
import sys


def parse(c):
    if c in (None, "", "transparent"):
        return (0.0, 0.0, 0.0, 0.0)
    c = c.strip()
    if c.startswith("#"):
        h = c[1:]
        if len(h) == 6:
            return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 1.0)
        if len(h) == 8:                              # qt writes #AARRGGBB
            return (int(h[2:4], 16), int(h[4:6], 16), int(h[6:8], 16), int(h[0:2], 16) / 255)
    raise ValueError(c)


def over(top, bottom):
    a = top[3]
    return tuple(top[i] * a + bottom[i] * (1 - a) for i in range(3)) + (1.0,)


def alpha(c, a):
    return c[:3] + (a,)


def lum(c):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * ch(c[0]) + 0.7152 * ch(c[1]) + 0.0722 * ch(c[2])


def ratio(a, b):
    la, lb = lum(a), lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


WHITE = (255, 255, 255, 1.0)
BACKDROPS = [(23, 23, 28, 1.0), (199, 199, 204, 1.0)]     # Theme.backdrops


def sel_fill(t, tint, under):
    """what a selected row looks like under its text (Theme.selFill)"""
    s = t["surface"]
    acc = parse(tint)
    acc2 = parse(t.get("accent2") or tint)
    mid = tuple((acc[i] + acc2[i]) / 2 for i in range(3)) + (1.0,)
    return {
        "gloss": over(alpha(WHITE, 0.10), over(alpha(acc, 0.62 if t.get("dark", True) else 0.90), under)),
        "block": over(alpha(acc, 0.92), under),
        "gradient": over(alpha(mid, 0.62), under),
        "soft": over(alpha(acc, 0.17), under),
        "ricepill": over(alpha(acc, 0.30), under),
        "lens": over(alpha(acc, 0.40), over(alpha(WHITE, 0.10), under)),
        "classic": acc,
        "p5": acc,
        "wii": WHITE,
        "nixie": over(alpha(acc, 0.12), under),
        "xmb": over(alpha(WHITE, 0.20), under),
        "chrome": over(alpha(acc, 0.35), (201, 207, 216, 1.0)),
    }.get(s, over(alpha(acc, 0.15), under))


CHECKS = [  # name, minimum (wcag: 4.5 body text, 3 large text / ui)
    ("text", 4.5), ("dim", 3.0), ("faint", 2.2), ("sel", 4.5), ("selDim", 3.0),
    ("field", 4.5), ("ink", 3.0), ("match", 3.0),
    ("okInk", 3.0), ("warnInk", 3.0), ("critInk", 3.0), ("critSel", 4.5),
]


def audit(t):
    worst = {}
    for bd in BACKDROPS:
        panel = over(parse(t["panelMid"]), bd)
        well = over(parse(t["well"]), panel)
        field = over(parse(t["field"]), panel)
        sel = sel_fill(t, t["fill"], well)
        on = lambda c, bg: ratio(over(parse(t[c]), bg), bg)
        vals = {
            "text": min(on("text", well), on("text", panel)),
            "dim": on("dim", well),
            "faint": on("faint", well),
            "sel": ratio(over(parse(t["selText"]), sel), sel),
            "selDim": ratio(over(parse(t["selDim"]), sel), sel),
            "field": on("text", field),
            "ink": on("ink", well),
            "match": on("match", well),
            "okInk": on("okInk", well),
            "warnInk": on("warnInk", well),
            "critInk": on("critInk", well),
            "critSel": ratio(parse(t["selText"]), sel_fill(t, t["critFill"], well)),
        }
        for k, v in vals.items():
            worst[k] = min(worst.get(k, 99), v)
    return worst


def main():
    files = sys.argv[1:]
    if not files:
        print(__doc__)
        sys.exit(2)
    worst, fails, palettes = {}, [], []
    for f in files:
        data = json.load(open(f))
        name = os.path.splitext(os.path.basename(f))[0]
        palettes.append(name)
        data.pop("_palette", None)
        data.pop("_widget", None)
        for tid, t in data.items():
            w = audit(t)
            row = worst.setdefault(tid, {})
            for n, lo in CHECKS:
                row[n] = min(row.get(n, 99), w[n])
                if w[n] < lo:
                    fails.append((tid, name, n, w[n], lo))
    print(f"{'theme':10}" + "".join(f"{n[:7]:>8}" for n, _ in CHECKS) + f"   worst of: {', '.join(palettes)}")
    for tid, row in worst.items():
        print(f"{tid:10}" + "".join(f"{row[n]:7.1f}{'!' if row[n] < lo else ' '}" for n, lo in CHECKS))
    print(f"\n{len(fails)} failures")
    for tid, pal, n, v, lo in fails:
        print(f"  {tid:10} {pal:8} {n:8} {v:4.1f} < {lo}")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
