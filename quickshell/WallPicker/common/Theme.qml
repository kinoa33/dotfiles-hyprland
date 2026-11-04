// ╔══════════════════════════════════════════════════════════════╗
// ║  Theme · one look shared by every widget (and waybar)        ║
// ║                                                              ║
// ║  each widget is either LINKED (wears the shared theme — pick ║
// ║  a theme for any linked widget and they all change) or has   ║
// ║  its OWN theme. state lives in one json file that every      ║
// ║  running widget watches, so changes land live everywhere:    ║
// ║    $XDG_STATE_HOME/quickshell-theme.json                     ║
// ║    { "shared": "neon", "widgets": { "waybar": "rice" },      ║
// ║      "motion": true }                                        ║
// ║  waybar and dunst can't run qml: the launcher daemon renders ║
// ║  their themes (ThemeExport.qml) and reloads them.            ║
// ║                                                              ║
// ║  themes are DATA, not code (format: themes/README.md):       ║
// ║    common/themes/builtin.json       the built-in looks       ║
// ║    ~/.config/quickshell/user-themes.json                     ║
// ║        made / edited in the theme studio (Super+Shift+T);    ║
// ║        an entry with a built-in's id overrides it            ║
// ║    $XDG_RUNTIME_DIR/quickshell-theme-draft.json              ║
// ║        the studio's unsaved edit, worn live while it's open  ║
// ║  every colour is a recipe over the walrs palette, so a rice  ║
// ║  re-colours all of them; then a contrast solver keeps text   ║
// ║  legible on any wallpaper (readable() below).                ║
// ╚══════════════════════════════════════════════════════════════╝
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    // which widget this process is — each widget sets it on start
    property string widget: ""

    readonly property var widgets: [
        { key: "launcher",      label: "launcher",       glyph: "󰀻" },
        { key: "waybar",        label: "waybar",         glyph: "󱔓" },
        { key: "notifications", label: "notifications",  glyph: "󰂚" },
        { key: "wallpicker",    label: "wallpapers",     glyph: "󰸉" },
        { key: "todo",          label: "todo",           glyph: "󰄲" },
        { key: "controlcenter", label: "control center", glyph: "󰘮" },
        { key: "screenshot",    label: "screenshots",    glyph: "\u{F0100}" },
        { key: "studio",        label: "theme studio",   glyph: "󰏘" }
    ]

    // the theme tab's chips; "mine" = themes you made or changed
    readonly property var cats: [
        { key: "",        label: "all" },
        { key: "glass",   label: "glass" },
        { key: "retro",   label: "retro" },
        { key: "console", label: "consoles" },
        { key: "mood",    label: "moods" },
        { key: "mine",    label: "mine" }
    ]
    function inCat(x, cat) {
        return cat === "" || (cat === "mine" ? (x.custom || x.modified) : x.cat === cat);
    }

    readonly property string fallbackId: "neon"

    // ── theme files ──────────────────────────────────────────────
    // QS_USER_THEMES / QS_THEME_DRAFT let a test rig use other files
    readonly property string builtinPath: String(Qt.resolvedUrl("themes/builtin.json")).replace(/^file:\/\//, "")
    readonly property string userPath: Quickshell.env("QS_USER_THEMES")
        || (Quickshell.env("HOME") + "/.config/quickshell/user-themes.json")
    readonly property string draftPath: Quickshell.env("QS_THEME_DRAFT")
        || ((Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-theme-draft.json")

    property var builtinSpecs: []          // ordered as shown in the theme tab
    property var userSpecs: []             // ordered as saved
    property var draft: null               // { id, spec } while the studio edits live
    property bool ignoreDraft: false       // the studio's own chrome never wears the draft

    readonly property var builtinMap: indexOf(builtinSpecs)
    readonly property var userMap: indexOf(userSpecs)
    function indexOf(list) {
        const m = {};
        for (const s of list) m[s.id] = s;
        return m;
    }

    // what the theme tabs list: built-ins in order (a user copy with the
    // same id stands in for one, flagged `modified`), then your own
    readonly property var themes: {
        const out = [];
        for (const b of builtinSpecs) {
            const u = userMap[b.id];
            out.push(metaOf(u || b, true, !!u));
        }
        for (const u of userSpecs)
            if (!builtinMap[u.id]) out.push(metaOf(u, false, false));
        return out;
    }
    function metaOf(s, builtin, modified) {
        return {
            id: s.id, cat: s.cat || "mine", label: s.label || s.id, glyph: s.glyph || "󰏘",
            blurb: s.blurb || "", builtin: builtin, modified: modified, custom: !builtin
        };
    }

    // the spec a theme id stands for right now: the studio's live draft,
    // else your saved copy, else the built-in
    function specOf(id, noDraft) {
        if (!noDraft && !ignoreDraft && draft && draft.id === id && draft.spec) return draft.spec;
        return userMap[id] || builtinMap[id] || null;
    }
    function builtinSpecOf(id) { return builtinMap[id] || null; }
    function isBuiltin(id) { return !!builtinMap[id]; }
    function isModified(id) { return !!builtinMap[id] && !!userMap[id]; }
    // a built-in exactly as shipped (no saved copy, no live draft)
    function isStock(id) {
        return !!builtinMap[id] && !userMap[id] && !(draft && draft.id === id && !ignoreDraft);
    }

    function parseSet(text) {
        const d = JSON.parse(text);
        const list = Array.isArray(d) ? d : (d && Array.isArray(d.themes) ? d.themes : []);
        return list.filter(s => s && typeof s.id === "string" && s.id !== "");
    }

    // every file is read once, blocking, while this singleton is created
    // (Component.onCompleted below), so a widget's first frame already wears
    // the right theme; after that they're watched and reloaded live
    FileView {
        id: builtinFile
        path: theme.builtinPath
        blockLoading: true
        onFileChanged: reload()
        onLoaded: theme.takeBuiltin(text())
    }
    FileView {
        id: userFile
        path: theme.userPath
        blockLoading: true
        atomicWrites: false                // rewrite in place: keeps everyone's inotify watch alive
        printErrors: false                 // no file yet = no user themes
        onFileChanged: reload()
        onLoaded: theme.takeUser(text())
    }
    FileView {
        id: draftFile
        path: theme.draftPath
        blockLoading: true
        atomicWrites: false
        printErrors: false
        onFileChanged: reload()
        onLoaded: theme.takeDraft(text())
    }
    function takeBuiltin(text) {
        try { theme.builtinSpecs = parseSet(text); }
        catch (e) { console.warn("theme: can't read " + builtinPath + ": " + e); }
    }
    function takeUser(text) {
        if (!text.trim()) { theme.userSpecs = []; return; }
        try { theme.userSpecs = parseSet(text); }
        catch (e) { console.warn("theme: can't read " + userPath + " (kept the last good copy): " + e); }
    }
    function takeDraft(text) {
        try {
            const d = JSON.parse(text || "{}");
            theme.draft = d && d.id && d.spec ? { id: String(d.id), spec: d.spec } : null;
        } catch (e) { theme.draft = null; }
    }
    function takeState(text) {
        try { theme.state = clone(JSON.parse(text)); } catch (e) {}
    }

    Component.onCompleted: {
        takeBuiltin(builtinFile.text());           // text() forces a blocking read
        takeUser(userFile.text());
        takeDraft(draftFile.text());
        takeState(file.text());
        for (const f of [builtinFile, userFile, draftFile, file])
            f.watchChanges = true;                 // only now: an early watch is set on an empty path
    }

    // ── writing themes (the studio) ──────────────────────────────
    function writeUser(list) {
        theme.userSpecs = list;
        userFile.setText(JSON.stringify({
            format: "quickshell-theme-set", version: 1,
            about: "your themes - made in the theme studio (Super+Shift+T). an entry with a built-in's id overrides it.",
            themes: list
        }, null, 2) + "\n");
    }
    // add or replace a user theme (a built-in's id = modify the built-in)
    function saveTheme(spec) {
        const list = userSpecs.filter(s => s.id !== spec.id);
        const at = userSpecs.findIndex(s => s.id === spec.id);
        if (at >= 0) list.splice(at, 0, spec); else list.push(spec);
        writeUser(list);
    }
    // delete a user theme — for a modified built-in this resets it
    function removeTheme(id) {
        writeUser(userSpecs.filter(s => s.id !== id));
    }
    function setDraft(id, spec) {
        theme.draft = { id: id, spec: spec };
        draftFile.setText(JSON.stringify({ id: id, spec: spec }) + "\n");
    }
    function clearDraft() {
        if (theme.draft === null && draftFile.text().trim() === "{}") return;
        theme.draft = null;
        draftFile.setText("{}\n");
    }
    // a fresh id that no theme uses yet: "aero" → "aero-2"
    function freeId(base) {
        base = String(base || "theme").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "theme";
        const taken = id => !!builtinMap[id] || !!userMap[id];
        if (!taken(base)) return base;
        const stem = base.replace(/-\d+$/, "");
        for (let i = 2; ; i++)
            if (!taken(stem + "-" + i)) return stem + "-" + i;
    }

    // ── state ────────────────────────────────────────────────────
    property var state: ({ shared: fallbackId, widgets: {}, motion: true })

    readonly property bool linked: isLinked(widget)
    // a theme tab can try a look on this widget before keeping it
    property string previewId: ""
    readonly property string current: previewId !== "" ? validId(previewId) : effectiveFor(widget)
    readonly property bool motion: state.motion !== false
    readonly property var t: tokens(current, widget)

    function validId(id) {
        if (themes.some(x => x.id === id)) return id;
        return themes.some(x => x.id === fallbackId) ? fallbackId : (themes.length ? themes[0].id : fallbackId);
    }
    function isLinked(w) {
        return !(state.widgets && state.widgets[w]);
    }
    function effectiveFor(w) {
        return validId((state.widgets && state.widgets[w]) || state.shared);
    }
    function labelOf(id) {
        const x = themes.find(t => t.id === id);
        return x ? x.label : id;
    }
    function widgetLabel(w) {
        const x = widgets.find(t => t.key === w);
        return x ? x.label : w;
    }

    function clone(s) {
        s = s || {};
        return { shared: validId(s.shared), widgets: Object.assign({}, s.widgets || {}), motion: s.motion !== false };
    }
    function commit(s) {
        theme.state = s;
        file.setText(JSON.stringify(s, null, 2) + "\n");
    }

    // pick a theme for widget w: linked → everyone linked changes
    function pickFor(w, id) {
        const s = clone(state);
        if (isLinked(w)) s.shared = validId(id);
        else s.widgets[w] = validId(id);
        commit(s);
    }
    // link: adopt the shared theme · unlink: keep the current look, privately
    function setLinkedFor(w, on) {
        const s = clone(state);
        if (on) delete s.widgets[w];
        else s.widgets[w] = effectiveFor(w);
        commit(s);
    }
    function pick(id) { pickFor(widget, id); }
    function setLinked(on) { setLinkedFor(widget, on); }
    function setMotion(on) {
        const s = clone(state);
        s.motion = on;
        commit(s);
    }
    function reload() {
        file.reload();
        userFile.reload();
        draftFile.reload();
        WalColors.reload();
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell-theme.json"
        blockLoading: true
        atomicWrites: false            // rewrite in place: keeps everyone's inotify watch alive
        printErrors: false
        onFileChanged: reload()
        onLoaded: theme.takeState(text())
    }

    // ── colour helpers ───────────────────────────────────────────
    function alpha(c, a) {
        const q = Qt.color(String(c));
        return Qt.rgba(q.r, q.g, q.b, a);
    }
    function mix(a, b, k, al) {
        const x = Qt.color(String(a)), y = Qt.color(String(b));
        return Qt.rgba(x.r + (y.r - x.r) * k, x.g + (y.g - x.g) * k, x.b + (y.b - x.b) * k,
                       al === undefined ? 1 : al);
    }
    // a livelier take on a palette colour (walrs palettes are often muted)
    function vivid(c, sat, light) {
        const q = Qt.color(String(c));
        if (q.hslHue < 0) return q;
        return Qt.hsla(q.hslHue, Math.min(1, q.hslSaturation * sat),
                       Math.min(0.92, Math.max(0.08, q.hslLightness + light)), 1);
    }
    // the palette colour, turned toward a hue (0…1) — keeps the rice's
    // lightness and some of its tone, borrows the hue
    function lean(c, hue, k, sat, light) {
        const q = Qt.color(String(c));
        const h0 = q.hslHue < 0 ? hue : q.hslHue;
        let d = hue - h0;
        if (d > 0.5) d -= 1;
        if (d < -0.5) d += 1;
        const h = (h0 + d * k + 1) % 1;
        return Qt.hsla(h, Math.min(1, Math.max(q.hslSaturation, 0.2) * sat),
                       Math.min(0.9, Math.max(0.1, q.hslLightness + light)), 1);
    }
    // free-form hsl adjustment: hue (absolute) or hueShift (degrees),
    // saturation and lightness as value × mul + add, clamped to [min, max]
    function tone(c, o) {
        const q = Qt.color(String(c));
        const num = (v, d) => typeof v === "number" && isFinite(v) ? v : d;
        let h = q.hslHue < 0 ? num(o.greyHue, 0) : q.hslHue;
        if (typeof o.hue === "number") h = o.hue;
        if (o.hueShift) h = ((h + o.hueShift / 360) % 1 + 1) % 1;
        const s = Math.min(num(o.satMax, 1), Math.max(num(o.satMin, 0), q.hslSaturation * num(o.satMul, 1) + num(o.satAdd, 0)));
        const l = Math.min(num(o.lightMax, 1), Math.max(num(o.lightMin, 0), q.hslLightness * num(o.lightMul, 1) + num(o.lightAdd, 0)));
        return Qt.hsla(h, s, l, q.a);
    }

    // ── the theme engine: spec → tokens ──────────────────────────
    // style keys every theme has (a spec only lists what it changes)
    readonly property var styleDefaults: ({
        font: "Pixel Code", glyphFont: "CaskaydiaCove Nerd Font",
        dark: true, radius: 16, radiusSm: 10, pillFull: false,
        surface: "flat", fx: "none", emblem: "glow",
        sheen: false, streak: false, swoosh: false, hairline: false, edge: false, bevel: false,
        wellInset: false, fieldInset: false, raisedText: false, glow: false, halo: false,
        shadow: 0.55
    })
    // colours a half-written spec falls back to (neon glass)
    readonly property var colorDefaults: ({
        accent: "color5", accent2: "color4", text: "fg", selText: "fg",
        panelTop: { from: "bg", alpha: 0.84 }, panelMid: { from: "bg", alpha: 0.84 }, panelBottom: { from: "bg", alpha: 0.86 },
        panelBorder: { from: "@accent", alpha: 0.38 }, rim: "transparent",
        well: "transparent", wellBorder: "transparent",
        field: { from: "fg", alpha: 0.06 }, fieldBorder: { from: "@accent", alpha: 0.24 }, fieldFocus: { from: "@accent", alpha: 0.6 }
    })
    // palette slots a recipe can start from
    readonly property var paletteSlots: ["bg", "fg", "color0", "color1", "color2", "color3", "color4", "color5", "color6", "color7",
                                         "color8", "color9", "color10", "color11", "color12", "color13", "color14", "color15", "ok", "warn", "crit"]
    function paletteRef(s) {
        switch (s) {
        case "bg": case "background": return WalColors.background;
        case "fg": case "foreground": return WalColors.foreground;
        case "ok": return WalColors.ok;
        case "warn": return WalColors.warn;
        case "crit": return WalColors.crit;
        }
        const m = /^color(\d{1,2})$/.exec(s);
        return m && +m[1] < 16 ? WalColors.slot(+m[1]) : undefined;
    }

    // the spec as worn by one widget: its overrides layered on top
    function resolve(spec, w) {
        const style = Object.assign({}, styleDefaults, spec.style || {});
        const colors = Object.assign({}, colorDefaults, spec.colors || {});
        const o = w && spec.widgets ? spec.widgets[w] : null;
        if (o) {
            Object.assign(style, o.style || {});
            Object.assign(colors, o.colors || {});
        }
        return { style: style, colors: colors };
    }

    // tokens are cached per (theme, widget) until the palette or any theme file moves
    readonly property var memo: ({ palette: WalColors.data, b: builtinSpecs, u: userSpecs, d: draft, i: ignoreDraft, cache: {} })
    function tokens(id, w, noDraft) {
        const m = theme.memo;
        const key = id + "|" + (w || "") + (noDraft ? "|nd" : "");
        if (m.cache[key]) return m.cache[key];
        const spec = specOf(id, noDraft) || specOf(validId(id), noDraft) || { id: id };
        const t = compile(spec, w);
        m.cache[key] = t;
        return t;
    }

    // a spec (saved, draft, or one being edited) → a token set
    function compile(spec, w) {
        const r = resolve(spec, w);
        const t = Object.assign({ id: spec.id, ok: WalColors.ok, warn: WalColors.warn, crit: WalColors.crit }, r.style);
        const env = { colors: r.colors, memo: {}, busy: {} };
        for (const name in r.colors) t[name] = namedColor(name, env);
        return r.style.contrast === "off" ? plain(t) : readable(t);
    }
    function namedColor(name, env) {
        if (name in env.memo) return env.memo[name];
        if (env.busy[name]) {
            console.warn("theme: colour '" + name + "' refers to itself");
            return "#ff00ff";
        }
        env.busy[name] = true;
        const v = evalColor(env.colors[name], env);
        env.busy[name] = false;
        env.memo[name] = v;
        return v;
    }
    // a colour reference: "@name" (another colour of the theme), a palette
    // slot ("bg", "color5", "ok" …), a literal ("#rrggbb", "transparent"),
    // or a recipe object
    function evalColor(x, env) {
        if (x === undefined || x === null || x === "") return "transparent";
        if (typeof x === "object") return recipe(x, env);
        const s = String(x).trim();
        if (s[0] === "@") {
            const n = s.slice(1);
            if (n in env.colors) return namedColor(n, env);
            const p = paletteRef(n);
            return p !== undefined ? p : "#ff00ff";
        }
        const p = paletteRef(s);
        return p !== undefined ? p : s;
    }
    // { from, lean, vivid, tone, lighter, darker, mix: [[ref, k] …], alpha }
    // applied in that order
    function recipe(r, env) {
        let c = evalColor(r.from === undefined ? "bg" : r.from, env);
        if (r.lean) c = lean(c, r.lean[0], r.lean[1], r.lean[2], r.lean[3]);
        if (r.vivid) c = vivid(c, r.vivid[0], r.vivid[1]);
        if (r.tone) c = tone(c, r.tone);
        if (r.lighter) c = Qt.lighter(String(c), r.lighter);
        if (r.darker) c = Qt.darker(String(c), r.darker);
        if (r.mix) for (const m of r.mix) c = mix(c, evalColor(m[0], env), m[1]);
        if (r.alpha !== undefined && r.alpha !== null) c = alpha(c, r.alpha);
        return c;
    }

    // ── contrast · every theme stays legible on any palette ──────
    // glass sits on an unknown wallpaper: each layer is judged over a dark
    // and a light backdrop and must pass on both (wcag: 4.5 body, 3 large)
    readonly property var backdrops: [Qt.rgba(0.09, 0.09, 0.11, 1), Qt.rgba(0.78, 0.78, 0.80, 1)]
    function lumOf(c) {
        const q = Qt.color(String(c));
        const ch = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * ch(q.r) + 0.7152 * ch(q.g) + 0.0722 * ch(q.b);
    }
    function contrast(a, b) {
        const la = lumOf(a), lb = lumOf(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }
    function over(top, bottom) {
        const f = Qt.color(String(top)), b = Qt.color(String(bottom)), a = f.a;
        return Qt.rgba(f.r * a + b.r * (1 - a), f.g * a + b.g * (1 - a), f.b * a + b.b * (1 - a), 1);
    }
    // worst contrast of colour c over each of the backgrounds
    function worst(c, bgs) {
        let w = 99;
        for (const b of bgs) w = Math.min(w, contrast(over(c, b), b));
        return w;
    }
    // walk c's lightness away from the backgrounds until it reads. first
    // away from the first backdrop (what a theme expects); glass over a
    // light palette can sit between a dark and a light wallpaper, so if
    // that way can't get there (or close), try the other way and keep
    // whichever reads better.
    function legible(c, bgs, target) {
        const q = Qt.color(String(c));
        if (worst(q, bgs) >= target) return q;
        const first = lumOf(bgs[0]) < 0.3;
        const a = walkLight(q, bgs, target, first);
        if (a.w >= target * 0.92) return a.c;      // reached it, or nearly: keep the theme's way
        const b = walkLight(q, bgs, target, !first);
        return b.w > a.w ? b.c : a.c;
    }
    function walkLight(q, bgs, target, up) {
        let l = q.hslLightness, n = q;
        for (let i = 0; i < 28; i++) {
            l = up ? Math.min(1, l + 0.03) : Math.max(0, l - 0.03);
            n = Qt.hsla(q.hslHue < 0 ? 0 : q.hslHue, q.hslSaturation, l, q.a);
            if (worst(n, bgs) >= target) break;
        }
        return { c: n, w: worst(n, bgs) };
    }
    // the lowest opacity of c that still reads (dim, faint)
    function minAlpha(c, bgs, a0, target) {
        for (let a = a0; a < 0.97; a += 0.04)
            if (worst(alpha(c, a), bgs) >= target) return a;
        return 0.97;
    }
    // what a selected row actually looks like under its text
    function selFill(t, tint, under) {
        const tn = Qt.color(String(tint));
        const mid = mix(tn, t.accent2 || tn, 0.5);
        switch (t.surface) {
        case "gloss":    return over(Qt.rgba(1, 1, 1, 0.10), over(alpha(tn, t.dark ? 0.62 : 0.90), under));  // mid-row, under the gloss line
        case "block":    return over(alpha(tn, 0.92), under);
        case "gradient": return over(alpha(mid, 0.62), under);
        case "soft":     return over(alpha(tn, 0.17), under);
        case "ricepill": return over(alpha(tn, 0.30), under);
        case "lens":     return over(alpha(tn, 0.40), over(Qt.rgba(1, 1, 1, 0.10), under));
        case "classic":
        case "p5":       return tn;
        case "wii":      return Qt.rgba(1, 1, 1, 1);
        case "nixie":    return over(alpha(tn, 0.12), under);
        case "xmb":      return over(Qt.rgba(1, 1, 1, 0.20), under);
        case "chrome":   return over(alpha(tn, 0.35), Qt.color("#c9cfd8"));
        default:         return over(alpha(tn, 0.15), under);
        }
    }

    function readable(t) {
        // what text sits on: the panel, and the well inside it
        const panels = backdrops.map(b => over(t.panelMid, b));
        const wells = panels.map(p => over(t.well, p));
        const under = wells.concat(panels);

        t.text = legible(t.text, under, 7.0);
        t.dim = alpha(t.text, minAlpha(t.text, under, 0.62, 3.6));
        t.faint = alpha(t.text, minAlpha(t.text, under, 0.40, 2.5));

        // accent as text: fuzzy-match letters, glyphs, "wears it" …
        t.ink = legible(t.accent, under, 3.6);
        if (t.match === undefined) t.match = t.dark ? legible(Qt.lighter(String(t.accent), 1.3), under, 4.0) : t.ink;
        else t.match = legible(t.match, under, 4.0);

        // status colours as text (wifi down, low battery, "clear done" …)
        t.okInk = legible(t.ok, under, 3.6);
        t.warnInk = legible(t.warn, under, 3.6);
        t.critInk = legible(t.crit, under, 3.6);
        // a red row with the selected text on it (the session menu's "press ⏎ again"):
        // darker red under light text, lighter red under dark text
        let cf = Qt.color(String(t.crit));
        const selLight = lumOf(t.selText) > 0.4;
        for (let i = 0; i < 28 && Math.min(...wells.map(w => contrast(t.selText, selFill(t, cf, w)))) < 4.6; i++)
            cf = Qt.hsla(cf.hslHue, cf.hslSaturation,
                         selLight ? Math.max(0.1, cf.hslLightness - 0.03) : Math.min(0.92, cf.hslLightness + 0.03), 1);
        t.critFill = cf;

        // the selection: keep its colour, move its lightness until the
        // selected text reads on it (white text darkens it, dark text lightens it)
        const fixedFill = ["wii", "xmb", "chrome", "soft", "ricepill", "nixie", "flat"].indexOf(t.surface) >= 0;
        let fill = Qt.color(String(t.accent));
        if (!fixedFill) {
            const textLight = lumOf(t.selText) > 0.4;
            let l = fill.hslLightness;
            for (let i = 0; i < 28; i++) {
                const fills = wells.map(w => selFill(t, fill, w));
                if (Math.min(...fills.map(f => contrast(t.selText, f))) >= 4.6) break;
                l = textLight ? Math.max(0.05, l - 0.025) : Math.min(0.95, l + 0.025);
                fill = Qt.hsla(fill.hslHue < 0 ? 0 : fill.hslHue, fill.hslSaturation, l, 1);
            }
        }
        t.fill = fill;
        // where the selection can't move, the selected text does — judged on
        // the accent row and on the red confirm row alike
        t.selText = legible(t.selText, wells.map(w => selFill(t, fill, w)).concat(wells.map(w => selFill(t, cf, w))), 4.6);
        t.selDim = alpha(t.selText, Math.max(0.72, minAlpha(t.selText, wells.map(w => selFill(t, fill, w)), 0.72, 3.2)));
        return t;
    }

    // contrast "off": the designer's colours exactly as written
    function plain(t) {
        t.dim = alpha(t.text, 0.62);
        t.faint = alpha(t.text, 0.40);
        t.ink = Qt.color(String(t.accent));
        t.match = t.match === undefined ? t.ink : Qt.color(String(t.match));
        t.okInk = t.ok;
        t.warnInk = t.warn;
        t.critInk = t.crit;
        t.critFill = Qt.color(String(t.crit));
        t.fill = Qt.color(String(t.accent));
        t.selDim = alpha(t.selText, 0.72);
        return t;
    }
}
