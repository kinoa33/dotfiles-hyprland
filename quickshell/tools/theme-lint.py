#!/usr/bin/env python3
"""theme-lint.py [file.json ...] — check theme files before (or after) you
hand-edit them. With no arguments it checks the built-ins
(common/themes/builtin.json) and your themes (~/.config/quickshell/user-themes.json).

It reports, per theme:
  errors    things Theme.qml can't use: missing id, duplicate ids, a colour
            that refers to a missing @name, a reference cycle, a malformed
            recipe step, an unknown surface / fx / emblem
  warnings  things that load but are probably mistakes: unknown style keys,
            unknown recipe keys, a helper named like a derived token, an
            unknown widget in "widgets"

The rules mirror common/Theme.qml (styleDefaults, paletteRef, recipe) and
the option lists in ThemeStudio/shell.qml. Exit status: 1 if any error.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

STYLE = {
    "font": str, "glyphFont": str, "dark": bool, "radius": (int, float), "radiusSm": (int, float),
    "pillFull": bool, "surface": str, "fx": str, "emblem": str, "titleStyle": str,
    "sheen": bool, "streak": bool, "swoosh": bool, "hairline": bool, "edge": bool, "bevel": bool,
    "wellInset": bool, "fieldInset": bool, "raisedText": bool, "glow": bool, "halo": bool,
    "shadow": (int, float), "contrast": str,
}
ENUMS = {
    "surface": {"flat", "gloss", "block", "gradient", "soft", "ricepill", "lens", "classic", "wii", "nixie", "xmb", "p5", "chrome"},
    "fx": {"none", "bubbles", "grid", "scanlines", "blobs", "banner", "petals", "aurora", "titlebar", "sweep", "eco", "wii",
           "divergence", "wave", "xbox", "dmg", "p5"},
    "emblem": {"glow", "orb", "prompt", "sun", "soft", "lens", "classic", "plain", "wii", "nixie", "luna", "p5"},
    "titleStyle": {"", "classic", "luna"},
    "contrast": {"auto", "off"},
}
CATS = {"glass", "retro", "console", "mood", "mine"}
WIDGETS = {"launcher", "waybar", "notifications", "wallpicker", "todo", "controlcenter", "screenshot", "studio"}
PALETTE = {"bg", "background", "fg", "foreground", "ok", "warn", "crit"} | {f"color{i}" for i in range(16)}
DERIVED = {"dim", "faint", "ink", "okInk", "warnInk", "critInk", "critFill", "fill", "selDim"}
DEFAULT_COLORS = {"accent", "accent2", "text", "selText", "panelTop", "panelMid", "panelBottom", "panelBorder", "rim",
                  "well", "wellBorder", "field", "fieldBorder", "fieldFocus"}
RECIPE = {"from", "lean", "vivid", "tone", "lighter", "darker", "mix", "alpha"}
TONE = {"hue", "hueShift", "greyHue", "satMul", "satAdd", "satMin", "satMax", "lightMul", "lightAdd", "lightMin", "lightMax"}
HEX = re.compile(r"^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")
NUM = (int, float)


def refs_of(value):
    """every @name a colour value points at"""
    out = []
    if isinstance(value, str):
        if value.startswith("@"):
            out.append(value[1:])
    elif isinstance(value, dict):
        out += refs_of(value.get("from", "bg"))
        for m in value.get("mix") or []:
            if isinstance(m, list) and m:
                out += refs_of(m[0])
    return out


def check_ref(ref, names, where, errs):
    if not isinstance(ref, str):
        errs.append(f"{where}: a reference must be a string, got {ref!r}")
    elif ref.startswith("@"):
        if ref[1:] not in names and ref[1:] not in PALETTE:
            errs.append(f"{where}: {ref} — no colour called {ref[1:]!r} in this theme")
    elif ref not in PALETTE and not HEX.match(ref) and ref != "transparent" and not re.match(r"^[a-z]+$", ref):
        errs.append(f"{where}: {ref!r} is neither a palette slot, @name, #hex nor a colour name")


def check_color(name, value, names, where, errs, warns):
    if isinstance(value, str):
        check_ref(value, names, where, errs)
        return
    if not isinstance(value, dict):
        errs.append(f"{where}: a colour is a reference string or a recipe object, got {type(value).__name__}")
        return
    for k in value:
        if k not in RECIPE:
            warns.append(f"{where}: unknown recipe key {k!r} (ignored)")
    check_ref(value.get("from", "bg"), names, where + ".from", errs)
    lean = value.get("lean")
    if lean is not None and not (isinstance(lean, list) and len(lean) == 4 and all(isinstance(x, NUM) for x in lean)):
        errs.append(f"{where}.lean: needs [hue, amount, sat×, light±], got {lean!r}")
    vivid = value.get("vivid")
    if vivid is not None and not (isinstance(vivid, list) and len(vivid) == 2 and all(isinstance(x, NUM) for x in vivid)):
        errs.append(f"{where}.vivid: needs [sat×, light±], got {vivid!r}")
    tone = value.get("tone")
    if tone is not None:
        if not isinstance(tone, dict):
            errs.append(f"{where}.tone: needs an object")
        else:
            for k, v in tone.items():
                if k not in TONE:
                    warns.append(f"{where}.tone: unknown key {k!r}")
                elif not isinstance(v, NUM):
                    errs.append(f"{where}.tone.{k}: needs a number")
    for k in ("lighter", "darker"):
        if k in value and not (isinstance(value[k], NUM) and value[k] > 0):
            errs.append(f"{where}.{k}: needs a positive factor")
    mix = value.get("mix")
    if mix is not None:
        if not isinstance(mix, list):
            errs.append(f"{where}.mix: needs [[ref, k], …]")
        else:
            for i, m in enumerate(mix):
                if not (isinstance(m, list) and len(m) == 2 and isinstance(m[1], NUM)):
                    errs.append(f"{where}.mix[{i}]: needs [ref, k]")
                else:
                    check_ref(m[0], names, f"{where}.mix[{i}]", errs)
    if "alpha" in value and not (isinstance(value["alpha"], NUM) and 0 <= value["alpha"] <= 1):
        errs.append(f"{where}.alpha: needs a number 0…1")


def check_style(style, where, errs, warns):
    if not isinstance(style, dict):
        errs.append(f"{where}: needs an object")
        return
    for k, v in style.items():
        if k not in STYLE:
            warns.append(f"{where}.{k}: unknown style key (ignored)")
            continue
        if not isinstance(v, STYLE[k]) or (STYLE[k] is not bool and isinstance(v, bool)):
            errs.append(f"{where}.{k}: wrong type {type(v).__name__}")
        elif k in ENUMS and v not in ENUMS[k]:
            errs.append(f"{where}.{k}: {v!r} isn't one of {', '.join(sorted(ENUMS[k] - {''}))}")


def cycles(colors):
    """names that refer to themselves through other colours"""
    bad, state = set(), {}

    def walk(n, stack):
        if state.get(n) == 2:
            return
        if state.get(n) == 1:
            bad.update(stack[stack.index(n):])
            return
        state[n] = 1
        for r in refs_of(colors.get(n)):
            if r in colors:
                walk(r, stack + [n])
        state[n] = 2

    for n in colors:
        walk(n, [])
    return bad


def check_spec(spec, errs, warns):
    sid = spec.get("id")
    if not isinstance(sid, str) or not sid:
        errs.append("a theme without an id")
        return
    if spec.get("cat") is not None and spec["cat"] not in CATS:
        warns.append(f"{sid}.cat: {spec['cat']!r} isn't one of {', '.join(sorted(CATS))} (it won't get a chip)")
    check_style(spec.get("style", {}), f"{sid}.style", errs, warns)
    colors = dict(spec.get("colors") or {})
    names = set(colors) | DEFAULT_COLORS
    for n, v in colors.items():
        if n in DERIVED:
            warns.append(f"{sid}.colors.{n}: named like a derived token — readable() overwrites it")
        check_color(n, v, names, f"{sid}.colors.{n}", errs, warns)
    for n in sorted(cycles(colors)):
        errs.append(f"{sid}.colors.{n}: refers to itself (through other colours)")
    for w, o in (spec.get("widgets") or {}).items():
        if w not in WIDGETS:
            warns.append(f"{sid}.widgets.{w}: not a widget the theme system knows ({', '.join(sorted(WIDGETS))})")
        if not isinstance(o, dict):
            errs.append(f"{sid}.widgets.{w}: needs an object")
            continue
        check_style(o.get("style", {}), f"{sid}.widgets.{w}.style", errs, warns)
        wcolors = dict(colors, **(o.get("colors") or {}))
        wnames = set(wcolors) | DEFAULT_COLORS
        for n, v in (o.get("colors") or {}).items():
            check_color(n, v, wnames, f"{sid}.widgets.{w}.colors.{n}", errs, warns)
        for n in sorted(cycles(wcolors) - cycles(colors)):
            errs.append(f"{sid}.widgets.{w}.colors.{n}: refers to itself")


def load(path):
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    return d if isinstance(d, list) else d.get("themes", [d] if "id" in d else [])


def main():
    paths = sys.argv[1:] or [os.path.join(ROOT, "common/themes/builtin.json"),
                             os.path.expanduser("~/.config/quickshell/user-themes.json")]
    bad = False
    for p in paths:
        if not os.path.exists(p):
            print(f"· {p}: none yet")
            continue
        try:
            specs = load(p)
        except (OSError, ValueError) as e:
            print(f"✗ {p}: not valid json — {e}")
            bad = True
            continue
        errs, warns, seen = [], [], set()
        for s in specs:
            if not isinstance(s, dict):
                errs.append(f"an entry that isn't an object: {s!r:.40}")
                continue
            if s.get("id") in seen:
                errs.append(f"{s.get('id')}: the id is used twice (the later one wins)")
            seen.add(s.get("id"))
            check_spec(s, errs, warns)
        mark = "✗" if errs else ("!" if warns else "✓")
        print(f"{mark} {p}: {len(specs)} themes, {len(errs)} errors, {len(warns)} warnings")
        for e in errs:
            print(f"    error    {e}")
        for w in warns:
            print(f"    warning  {w}")
        bad |= bool(errs)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
