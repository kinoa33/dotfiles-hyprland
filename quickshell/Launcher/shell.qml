// ╔══════════════════════════════════════════════════════════════╗
// ║  launcher (quickshell) · themed by common/Theme.qml          ║
// ║  frutiger aero · neon glass · phosphor · vaporwave · frost   ║
// ║  — all tinted by the walrs palette, set in Pixel Code.       ║
// ║  runs as a daemon (autostart.conf), opened over IPC:         ║
// ║  hypr/scripts/launcher.sh [apps|windows|run|clip|session|theme]
// ║                                                              ║
// ║  modes   apps      fuzzy search · favourites · app actions   ║
// ║                    = calc / units (5 km to mi, 0xff, 15% of) ║
// ║                    ? web  (?yt ?w ?aw ?aur ?gh ?r ?g …)      ║
// ║                    > run   + todo (!! @fri)   : emoji        ║
// ║                    / files in your home                      ║
// ║          windows   every open window · alt-tab style         ║
// ║          run       shell command · history · $PATH complete  ║
// ║          clip      cliphist history with a live preview      ║
// ║          session   lock · idle mode · suspend · power        ║
// ║          theme     pick a look · link it to the other widgets║
// ║                                                              ║
// ║  keys    ↑↓ / ctrl-j,k  move      tab / shift-tab  mode      ║
// ║          ⏎ open   ⇧⏎ in terminal   alt-1…6  jump to mode     ║
// ║          → app actions (← back)    ctrl-s  pin to favourites ║
// ║          ctrl-h  hide an app from the list (search still finds)║
// ║          ctrl-1…7  launch favourite (hold ctrl to see them)  ║
// ║          ⇧del  remove clip / close window      esc  close    ║
// ║          ctrl-⇧del twice (or "clear all")  wipe the clipboard ║
// ║          history                                             ║
// ╚══════════════════════════════════════════════════════════════╝
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "common"
import "common/todo.js" as Todo

ShellRoot {
    id: shell

    // ── tweakables ───────────────────────────────────────────────
    readonly property string terminal: "kitty"
    readonly property string webSearch: "https://search.brave.com/search?q="
    // "?yt lofi" searches youtube, and so on
    readonly property var engines: ({
        g:   { name: "google",     url: "https://www.google.com/search?q=" },
        yt:  { name: "youtube",    url: "https://www.youtube.com/results?search_query=" },
        w:   { name: "wikipedia",  url: "https://en.wikipedia.org/w/index.php?search=" },
        aw:  { name: "arch wiki",  url: "https://wiki.archlinux.org/index.php?search=" },
        aur: { name: "aur",        url: "https://aur.archlinux.org/packages?K=" },
        gh:  { name: "github",     url: "https://github.com/search?q=" },
        r:   { name: "reddit",     url: "https://www.reddit.com/search/?q=" }
    })
    readonly property int idleLockMin: 30          // shown in the session menu
    readonly property int favCount: 7
    // favourites before you've pinned anything (skipped if not installed)
    readonly property var defaultPins: ["kitty", "brave-browser", "org.kde.dolphin", "obsidian", "vesktop"]

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
    readonly property string stateDir: stateHome + "/quickshell-launcher"
    readonly property string runDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-launcher"

    // ── state ────────────────────────────────────────────────────
    property bool shown: false
    property string mode: "apps"
    property string query: ""
    property var results: []
    property int armed: -1                          // session row waiting for a 2nd ⏎
    property var targetScreen: null
    property bool ctrlHeld: false
    property point pointer: Qt.point(-1, -1)        // last real pointer position (scene)

    property var apps: []                           // indexed desktop entries
    property var favs: []                           // favourites strip
    property var bins: []                           // $PATH executables
    property var clips: []                          // cliphist rows
    property bool clipsLoading: false
    property var wins: []                           // hyprland clients
    property bool idleOn: true
    property var usage: ({ apps: {}, runs: [], pins: defaultPins.slice(), hidden: [], emoji: [] })
    property var emoji: []                          // [{ c, name }] from emoji.tsv, read on first ":"
    property var files: []                          // "/" search results
    property string filesFor: ""                    // the query they answer

    property var subApp: null                       // app whose actions are listed
    property var subPrev: null                      // { query, index } to go back to

    property string previewFor: ""                  // clip id on show in the preview
    property string previewText: ""
    property bool wipeArmed: false                  // "clear all" waiting for its second press
    property string previewImage: ""

    readonly property var modeDefs: [
        { key: "apps",    label: "apps",      glyph: "󰀻", hint: "search apps…  = calc  ? web  > run  + todo  : emoji  / files" },
        { key: "windows", label: "windows",   glyph: "󰖯", hint: "switch to a window…" },
        { key: "run",     label: "run",       glyph: "󰆍", hint: "run a command…" },
        { key: "clip",    label: "clipboard", glyph: "󰅌", hint: "search clipboard history…" },
        { key: "session", label: "session",   glyph: "󰐥", hint: "lock, suspend, power…" },
        { key: "theme",   label: "theme",     glyph: "󰏘", hint: "search themes…  xbox · light · retro" }
    ]
    readonly property var modeDef: modeDefs.find(m => m.key === mode) || modeDefs[0]

    // ── helpers ──────────────────────────────────────────────────
    function esc(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    property var iconCache: ({})
    function iconFor(name) {
        if (!name) return "";
        if (name in iconCache) return iconCache[name];
        const url = name.startsWith("/") ? "file://" + name : Quickshell.iconPath(name, true);
        iconCache[name] = url || "";
        return iconCache[name];
    }

    property var classIcons: ({})
    function iconForClass(cls) {
        if (!cls) return "";
        if (cls in classIcons) return classIcons[cls];
        const e = DesktopEntries.heuristicLookup(cls);
        classIcons[cls] = iconFor(e ? e.icon : cls) || iconFor(cls.toLowerCase());
        return classIcons[cls];
    }

    // fuzzy score: prefix > word-boundary substring > substring > subsequence.
    // -1 = no match. q and s are lowercase.
    function fuzzy(q, s) {
        if (!q) return 0;
        if (!s) return -1;
        const i = s.indexOf(q);
        if (i === 0) return 1000 - s.length;
        if (i > 0) return (/[\s\-_.\/]/.test(s[i - 1]) ? 850 : 650) - i - s.length * 0.5;
        let si = 0, sc = 0, run = 0, first = -1, last = -2;
        for (let k = 0; k < q.length; k++) {
            const c = q[k];
            if (c === " ") continue;
            const f = s.indexOf(c, si);
            if (f < 0) return -1;
            if (first < 0) first = f;
            run = f === last + 1 ? run + 1 : 0;
            sc += 2 + run * 4;
            if (f === 0 || /[\s\-_.\/]/.test(s[f - 1])) sc += 12;     // initials: "vsc"
            last = f;
            si = f + 1;
        }
        return 200 + sc - first * 2 - (last - first - q.length) - s.length * 0.2;
    }

    // which characters to light up for a match
    function matchIdx(q, s) {
        q = q.replace(/\s+/g, " ").trim();
        if (!q) return [];
        const i = s.indexOf(q);
        if (i >= 0) return Array.from({ length: q.length }, (_, k) => i + k);
        const out = [];
        let si = 0;
        for (const c of q) {
            if (c === " ") continue;
            const f = s.indexOf(c, si);
            if (f < 0) return [];
            out.push(f);
            si = f + 1;
        }
        return out;
    }

    function highlight(text, q, color) {
        text = String(text);
        const hit = new Set(matchIdx(q.toLowerCase(), text.toLowerCase()));
        if (!hit.size) return esc(text);
        let out = "", on = false;
        for (let k = 0; k < text.length; k++) {
            const m = hit.has(k);
            if (m && !on) { out += "<font color='" + color + "'><b>"; on = true; }
            if (!m && on) { out += "</b></font>"; on = false; }
            out += esc(text[k]);
        }
        return on ? out + "</b></font>" : out;
    }

    // ── usage · frecency, pins, run history ──────────────────────
    FileView {
        id: usageFile
        path: shell.stateDir + "/usage.json"
        printErrors: false
        onLoaded: {
            try {
                const u = JSON.parse(text());
                shell.usage = { apps: u.apps || {}, runs: u.runs || [],
                                pins: Array.isArray(u.pins) ? u.pins : shell.defaultPins.slice(),
                                hidden: u.hidden || [], emoji: u.emoji || [] };
                shell.updateFavs();
            } catch (e) {}
        }
    }

    function saveUsage() {
        usageFile.setText(JSON.stringify(shell.usage));
    }

    function frecency(id) {
        const u = shell.usage.apps[id];
        if (!u) return 0;
        const hours = (Date.now() - u.t) / 3.6e6;
        const w = hours < 6 ? 4 : hours < 48 ? 2 : hours < 24 * 14 ? 1 : 0.4;
        return u.n * w;
    }

    function bumpApp(id) {
        const u = shell.usage.apps[id] || { n: 0, t: 0 };
        u.n = Math.min(u.n + 1, 500);
        u.t = Date.now();
        shell.usage.apps[id] = u;
        saveUsage();
    }

    function rememberRun(cmd) {
        const runs = shell.usage.runs.filter(c => c !== cmd);
        runs.unshift(cmd);
        shell.usage.runs = runs.slice(0, 60);
        saveUsage();
    }

    function isPinned(id) {
        return shell.usage.pins.indexOf(id) >= 0;
    }

    function togglePin(id) {
        const pins = shell.usage.pins.filter(p => p !== id);
        if (pins.length === shell.usage.pins.length) pins.push(id);
        shell.usage.pins = pins;
        saveUsage();
        updateFavs();
        refresh(true);
    }

    function isHidden(id) {
        return shell.usage.hidden.indexOf(id) >= 0;
    }

    // hidden apps leave the list and the favourites; a search still finds them
    function toggleHidden(id) {
        const h = shell.usage.hidden.filter(x => x !== id);
        if (h.length === shell.usage.hidden.length) h.push(id);
        shell.usage.hidden = h;
        saveUsage();
        updateFavs();
        refresh(true);
    }

    // pinned first (in pin order), then the most used, up to favCount
    function updateFavs() {
        const byId = {};
        for (const a of shell.apps) byId[a.id] = a;
        const out = [], seen = {};
        for (const id of shell.usage.pins) {
            if (!byId[id] || seen[id]) continue;
            seen[id] = true;
            out.push({ app: byId[id], icon: iconFor(byId[id].icon), pinned: true });
        }
        const ranked = shell.apps.filter(a => !seen[a.id] && !isHidden(a.id) && frecency(a.id) > 0)
                                 .sort((x, y) => frecency(y.id) - frecency(x.id));
        for (const a of ranked) out.push({ app: a, icon: iconFor(a.icon), pinned: false });
        shell.favs = out.slice(0, shell.favCount);
    }

    // ── sources ──────────────────────────────────────────────────
    function reindex() {
        const vals = Array.from(DesktopEntries.applications.values);
        const out = [], seen = {};
        for (const e of vals) {
            if (!e || e.noDisplay || seen[e.id]) continue;
            seen[e.id] = true;
            out.push({
                entry: e,
                id: e.id,
                name: e.name,
                sub: e.genericName || e.comment || "",
                icon: e.icon,
                terminal: e.runInTerminal,
                actions: Array.from(e.actions || []),
                _n: e.name.toLowerCase(),
                _g: (e.genericName || "").toLowerCase(),
                _k: Array.from(e.keywords || []).join(" ").toLowerCase(),
                _c: (e.comment || "").toLowerCase(),
                _i: e.id.toLowerCase()
            });
        }
        out.sort((a, b) => a._n.localeCompare(b._n));
        shell.apps = out;
        updateFavs();
        if (shell.shown && shell.mode === "apps") refresh(true);
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { reindexDebounce.restart(); }
    }
    Timer { id: reindexDebounce; interval: 300; onTriggered: shell.reindex() }

    Process {
        id: binsProc
        command: ["sh", "-c",
            "IFS=:; for d in $PATH; do [ -d \"$d\" ] && ls -1 \"$d\"; done 2>/dev/null | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: shell.bins = text.split("\n").filter(s => s && !s.startsWith("."))
        }
    }

    Process {
        id: clipProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    const body = line.slice(tab + 1).replace(/\u0000/g, "");   // utf-16 copies
                    const img = body.match(/^\[\[ binary data (.+?) (\w+) (\d+x\d+) \]\]$/);
                    out.push({
                        line: line,
                        id: line.slice(0, tab),
                        image: !!img,
                        ext: img ? img[2] : "",
                        text: img ? "image  ·  " + img[2] + "  " + img[3] : body.replace(/\s+/g, " ").trim(),
                        size: img ? img[1] : body.length + " chars",
                        _t: body.toLowerCase()
                    });
                }
                shell.clips = out;
                shell.clipsLoading = false;
                if (shell.mode === "clip") shell.refresh(false);
            }
        }
    }

    Process {
        id: winProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try { list = JSON.parse(text); } catch (e) {}
                shell.wins = list
                    .filter(c => c.mapped && !c.hidden && c.workspace && c.workspace.id !== -1)
                    .sort((a, b) => a.focusHistoryID - b.focusHistoryID)
                    .map(c => ({
                        addr: c.address,
                        cls: c.class || c.initialClass || "",
                        title: c.title || c.class || "window",
                        ws: c.workspace.name.startsWith("special") ? "scratchpad" : "ws " + c.workspace.name,
                        flags: [c.fullscreen ? "fullscreen" : "", c.floating ? "floating" : "",
                                c.pinned ? "pinned" : ""].filter(f => f).join(" · "),
                        _t: ((c.title || "") + " " + (c.class || "")).toLowerCase()
                    }));
                if (shell.mode === "windows") {
                    shell.refresh(false);
                    // alt-tab: start on the window you were on *before* this one
                    if (shell.query === "" && shell.results.length > 1) shell.select(1);
                }
            }
        }
    }

    FileView {
        id: idleFile
        path: shell.stateHome + "/idle-mode/mode"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: shell.setIdle(text().trim() !== "off")
        onLoadFailed: shell.setIdle(true)
    }
    function setIdle(on) {
        if (shell.idleOn === on) return;
        shell.idleOn = on;
        if (shell.mode === "session") refresh(true);
    }

    // ── clipboard preview · decoded on demand, cached in $XDG_RUNTIME_DIR
    Timer { id: previewTimer; interval: 110; onTriggered: shell.loadPreview() }

    function loadPreview() {
        const r = shell.results[list.currentIndex];
        if (shell.mode !== "clip" || !r || r.kind !== "clip") {
            shell.previewFor = "";
            return;
        }
        if (shell.previewFor === r.clip.id) return;
        shell.previewFor = r.clip.id;
        shell.previewText = "";
        shell.previewImage = "";
        previewProc.running = false;
        previewProc.command = r.clip.image
            ? ["sh", "-c", 'mkdir -p "$1"; f="$1/clip-$2.$3"; ' +
                           '[ -s "$f" ] || printf "%s" "$4" | cliphist decode > "$f"; ' +
                           'printf "%s\\tIMG\\t%s" "$2" "$f"',
               "preview", shell.runDir, r.clip.id, r.clip.ext || "png", r.clip.line]
            : ["sh", "-c", 'printf "%s\\tTXT\\t" "$1"; printf "%s" "$2" | cliphist decode | head -c 6000',
               "preview", r.clip.id, r.clip.line];
        previewProc.running = true;
    }

    Process {
        id: previewProc
        stdout: StdioCollector {
            onStreamFinished: {
                const a = text.indexOf("\t"), b = text.indexOf("\t", a + 1);
                if (a < 0 || b < 0 || text.slice(0, a) !== shell.previewFor) return;   // stale
                const kind = text.slice(a + 1, b), body = text.slice(b + 1);
                if (kind === "IMG") shell.previewImage = "file://" + body;
                else shell.previewText = body;
            }
        }
    }

    // ── result builders ──────────────────────────────────────────
    function tryCalc(raw) {
        let s = raw.trim();
        const forced = s.startsWith("=");
        if (forced) s = s.slice(1).trim();
        if (!s || !/\d/.test(s)) return null;
        const fns = ["sqrt", "cbrt", "sin", "cos", "tan", "asin", "acos", "atan", "log", "log2",
                     "log10", "exp", "abs", "round", "floor", "ceil", "pow", "min", "max", "PI", "E"];
        let expr = s.replace(/\^/g, "**").replace(/\bpi\b/gi, "PI").replace(/\bln\b/g, "log");
        if (!/^[\d\s+\-*\/%().,A-Za-z_]*$/.test(expr)) return null;
        const ids = expr.match(/[A-Za-z_]\w*/g) || [];
        if (ids.some(id => !fns.includes(id))) return null;
        // without "=", only treat it as maths when there is maths in it
        if (!forced && !ids.length && !/[\d)]\s*(\*\*|[-+*\/%])\s*[\d(.]/.test(expr)) return null;
        expr = expr.replace(/[A-Za-z_]\w*/g, m => "Math." + m);
        try {
            const v = Function("\"use strict\"; return (" + expr + ");")();
            if (typeof v !== "number" || !isFinite(v)) return null;
            return String(Number.isInteger(v) ? v : parseFloat(v.toPrecision(12)));
        } catch (e) {
            return null;
        }
    }

    // ── units · "5 km to mi", "100f in c", "2 gib to mb" ─────────
    // factor to the family's base unit; temperatures are special-cased
    readonly property var units: {
        const u = {}, add = (fam, f, names) => { for (const n of names) u[n] = { fam: fam, f: f, name: names[0] }; };
        add("len", 0.001, ["mm", "millimeter", "millimeters", "millimetre", "millimetres"]);
        add("len", 0.01, ["cm", "centimeter", "centimeters", "centimetre", "centimetres"]);
        add("len", 1, ["m", "meter", "meters", "metre", "metres"]);
        add("len", 1000, ["km", "kilometer", "kilometers", "kilometre", "kilometres"]);
        add("len", 0.0254, ["in", "inch", "inches"]);
        add("len", 0.3048, ["ft", "foot", "feet"]);
        add("len", 0.9144, ["yd", "yard", "yards"]);
        add("len", 1609.344, ["mi", "mile", "miles"]);
        add("len", 1852, ["nmi", "nauticalmile"]);
        add("mass", 0.001, ["mg", "milligram", "milligrams"]);
        add("mass", 1, ["g", "gram", "grams"]);
        add("mass", 1000, ["kg", "kilo", "kilos", "kilogram", "kilograms"]);
        add("mass", 1e6, ["t", "tonne", "tonnes", "ton", "tons"]);
        add("mass", 28.349523125, ["oz", "ounce", "ounces"]);
        add("mass", 453.59237, ["lb", "lbs", "pound", "pounds"]);
        add("mass", 6350.29318, ["st", "stone", "stones"]);
        add("time", 0.001, ["ms", "millisecond", "milliseconds"]);
        add("time", 1, ["s", "sec", "secs", "second", "seconds"]);
        add("time", 60, ["min", "mins", "minute", "minutes"]);
        add("time", 3600, ["h", "hr", "hrs", "hour", "hours"]);
        add("time", 86400, ["d", "day", "days"]);
        add("time", 604800, ["wk", "week", "weeks"]);
        add("time", 31557600, ["yr", "year", "years"]);
        add("data", 1, ["b", "byte", "bytes"]);
        add("data", 1e3, ["kb"]); add("data", 1e6, ["mb"]); add("data", 1e9, ["gb"]); add("data", 1e12, ["tb"]);
        add("data", 1024, ["kib"]); add("data", 1048576, ["mib"]); add("data", 1073741824, ["gib"]);
        add("data", 1099511627776, ["tib"]);
        add("vol", 0.001, ["ml", "milliliter", "milliliters", "millilitre", "millilitres"]);
        add("vol", 1, ["l", "liter", "liters", "litre", "litres"]);
        add("vol", 3.785411784, ["gal", "gallon", "gallons"]);
        add("vol", 0.2365882365, ["cup", "cups"]);
        add("vol", 0.0295735295625, ["floz"]);
        add("speed", 1, ["m/s", "mps"]);
        add("speed", 1 / 3.6, ["km/h", "kmh", "kph"]);
        add("speed", 0.44704, ["mph"]);
        add("speed", 0.514444, ["kn", "knot", "knots"]);
        add("temp", 0, ["c", "°c", "celsius"]);
        add("temp", 0, ["f", "°f", "fahrenheit"]);
        add("temp", 0, ["k", "kelvin"]);
        return u;
    }
    function nice(v) {
        return String(Number.isInteger(v) ? v : parseFloat(v.toPrecision(7)));
    }
    function tryConvert(raw) {
        const s = raw.trim().replace(/^=\s*/, "").toLowerCase();
        // bases: "0xff" · "0b1010" · "255 to hex"
        let m = s.match(/^(0x[0-9a-f]+|0b[01]+|0o[0-7]+)(?:\s+(?:to|in)\s+(hex|bin|oct|dec))?$/);
        if (m) {
            const v = parseInt(m[1].slice(2), m[1][1] === "x" ? 16 : m[1][1] === "b" ? 2 : 8);
            const to = m[2] || "dec";
            const out = to === "hex" ? "0x" + v.toString(16) : to === "bin" ? "0b" + v.toString(2)
                      : to === "oct" ? "0o" + v.toString(8) : String(v);
            return { value: out, sub: m[1] + "  =  " + v + "  ·  0x" + v.toString(16) + "  ·  0b" + v.toString(2) };
        }
        m = s.match(/^(-?\d+)\s+(?:to|in)\s+(hex|bin|oct)$/);
        if (m) {
            const v = parseInt(m[1], 10);
            const out = m[2] === "hex" ? "0x" + v.toString(16) : m[2] === "bin" ? "0b" + v.toString(2) : "0o" + v.toString(8);
            return { value: out, sub: m[1] + " in " + m[2] };
        }
        // "15% of 80"
        m = s.match(/^(-?[\d.]+)\s*%\s*of\s+(-?[\d.]+)$/);
        if (m) return { value: nice(Number(m[1]) / 100 * Number(m[2])), sub: m[1] + "% of " + m[2] };
        // units
        m = s.match(/^(-?[\d.]+(?:e-?\d+)?)\s*([a-z°\/]+)\s+(?:to|in|as|->)\s+([a-z°\/]+)$/);
        if (!m) return null;
        const a = shell.units[m[2]], b = shell.units[m[3]], x = Number(m[1]);
        if (!a || !b || a.fam !== b.fam || isNaN(x)) return null;
        let v;
        if (a.fam === "temp") {
            const k = a.name === "c" ? x + 273.15 : a.name === "f" ? (x - 32) * 5 / 9 + 273.15 : x;
            v = b.name === "c" ? k - 273.15 : b.name === "f" ? (k - 273.15) * 9 / 5 + 32 : k;
        } else {
            v = x * a.f / b.f;
        }
        return { value: nice(v), unit: b.name === "c" || b.name === "f" ? "°" + b.name.toUpperCase() : b.name === "k" ? "K" : m[3],
                 sub: m[1] + " " + m[2] };
    }

    function appRow(a, recent) {
        const pinned = isPinned(a.id);
        const hidden = isHidden(a.id);
        return { kind: "app", app: a, title: a.name, sub: (hidden ? "hidden  ·  " : "") + a.sub, icon: iconFor(a.icon), glyph: "󰣆",
                 badge: (pinned ? "󰐃" : recent ? "󰋚" : "") + "  󰅂" };
    }

    function webRow(w) {
        const m = w.match(/^(\w+)\s+(.+)$/);
        const e = m && shell.engines[m[1].toLowerCase()];
        if (e)
            return { kind: "web", glyph: "󰖟", title: "search " + e.name + " for  " + m[2], plain: true,
                     sub: e.url.replace(/^https?:\/\//, "").split("/")[0], url: e.url + encodeURIComponent(m[2]) };
        return { kind: "web", glyph: "󰖟", title: "search the web for  " + w, plain: true,
                 sub: shell.webSearch.replace(/^https?:\/\//, "").split("/")[0],
                 url: shell.webSearch + encodeURIComponent(w) };
    }

    // ── "+ task" → the todo list (common/todo.js) ────────────────
    function todoResults(raw) {
        const e = Todo.parseEntry(raw);
        if (!e.title)
            return [{ kind: "hint", glyph: "\u{F0132}", title: "add a task to the todo list", plain: true,
                      sub: "+ buy milk !! @fri   ·   ! !! !!! priority   ·   @today @tom @mon @+3 @10-24 due" }];
        const bits = [];
        if (e.prio) bits.push("!!!".slice(0, e.prio) + " " + Todo.prioNames[e.prio]);
        if (e.due) bits.push("due " + Todo.dueLabel(e.due));
        bits.push("⏎ adds it");
        return [{ kind: "todo", glyph: "\u{F0132}", title: "add to todo:  " + e.title, plain: true,
                  text: raw, sub: bits.join("   ·   ") }];
    }

    // ── ": name" → emoji, copied ──────────────────────────────────
    FileView {
        id: emojiFile
        path: Quickshell.shellDir + "/emoji.tsv"
        printErrors: false
        onLoaded: {
            shell.emoji = text().split("\n").filter(l => l).map(l => {
                const t = l.indexOf("\t");
                return { c: l.slice(0, t), name: l.slice(t + 1) };
            });
            if (shell.shown && shell.mode === "apps") shell.refresh(false);
        }
    }
    function emojiResults(raw) {
        if (!shell.emoji.length) { emojiFile.reload(); return [{ kind: "hint", glyph: "…", title: "reading emoji…", plain: true }]; }
        const words = raw.trim().toLowerCase().split(/\s+/).filter(w => w);
        const out = [];
        if (!words.length) {                        // recently used first
            for (const c of shell.usage.emoji) {
                const e = shell.emoji.find(x => x.c === c);
                if (e) out.push(emojiRow(e, true));
            }
            if (!out.length)
                out.push({ kind: "hint", glyph: "😀", title: "type a name:  :heart  :fire  :thumbs", plain: true,
                           sub: "⏎ copies the emoji" });
            return out;
        }
        const scored = [];
        for (const e of shell.emoji) {
            if (!words.every(w => e.name.indexOf(w) >= 0)) continue;
            const i = e.name.indexOf(words[0]);
            const word = i === 0 || e.name[i - 1] === " ";
            scored.push({ e: e, s: (i === 0 ? 300 : word ? 200 : 0) - e.name.length + (shell.usage.emoji.indexOf(e.c) >= 0 ? 150 : 0) });
        }
        scored.sort((x, y) => y.s - x.s);
        for (const r of scored.slice(0, 80)) out.push(emojiRow(r.e, false));
        return out;
    }
    function emojiRow(e, recent) {
        return { kind: "emoji", glyph: e.c, emoji: true, title: e.name, char: e.c,
                 sub: recent ? "recent   ·   ⏎ copies it" : "⏎ copies it", badge: recent ? "󰋚" : "" };
    }
    function rememberEmoji(c) {
        shell.usage.emoji = [c].concat(shell.usage.emoji.filter(x => x !== c)).slice(0, 24);
        saveUsage();
    }

    // ── "/ name" → files under $HOME (not hidden dirs), async ─────
    Timer { id: filesTimer; interval: 140; onTriggered: shell.findFiles() }
    function findFiles() {
        const q = shell.query.trim().slice(1).trim();
        if (!q) return;
        filesProc.running = false;
        filesProc.q = q;
        filesProc.command = ["sh", "-c",
            'find "$HOME" -maxdepth 6 \\( -name ".*" -o -name node_modules -o -name __pycache__ \\) -prune ' +
            '-o -iname "*$1*" -printf "%y\\t%p\\n" 2>/dev/null | head -80', "find", q];
        filesProc.running = true;
    }
    Process {
        id: filesProc
        property string q: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const home = shell.home;
                shell.files = text.split("\n").filter(l => l).map(l => {
                    const dir = l[0] === "d", p = l.slice(2);
                    return { path: p, dir: dir, name: p.split("/").pop(), rel: "~" + p.slice(home.length) };
                });
                shell.filesFor = filesProc.q;
                if (shell.mode === "apps" && shell.query.trim().startsWith("/")) shell.refresh(false);
            }
        }
    }
    function fileGlyph(f) {
        if (f.dir) return "\u{F024B}";
        const ext = (f.name.match(/\.(\w+)$/) || ["", ""])[1].toLowerCase();
        if (["png", "jpg", "jpeg", "webp", "gif", "svg", "bmp"].includes(ext)) return "\u{F021F}";
        if (["mp4", "mkv", "webm", "mov", "avi"].includes(ext)) return "\u{F022B}";
        if (["mp3", "flac", "ogg", "wav", "opus", "m4a"].includes(ext)) return "\u{F0223}";
        if (ext === "pdf") return "\u{F0226}";
        return "\u{F0214}";
    }
    function fileResults(raw) {
        const q = raw.trim().slice(1).trim();
        if (!q)
            return [{ kind: "hint", glyph: "\u{F024B}", title: "find a file in your home folder", plain: true,
                      sub: "/ notes   ·   ⏎ opens it   ·   ⇧⏎ shows it in the file manager" }];
        filesTimer.restart();
        const ql = q.toLowerCase();
        const out = [];
        for (const f of shell.files) {
            if (f.name.toLowerCase().indexOf(ql) < 0) continue;
            out.push({ kind: "file", file: f, glyph: fileGlyph(f), title: f.name, sub: f.rel, query: q,
                       badge: f.dir ? "folder" : "" });
        }
        // a name match beats a deep path; shorter paths first
        out.sort((a, b) => (b.title.toLowerCase().startsWith(ql) - a.title.toLowerCase().startsWith(ql))
                           || (a.sub.split("/").length - b.sub.split("/").length));
        if (!out.length)
            out.push({ kind: "hint", glyph: "…", plain: true,
                       title: filesProc.running || shell.filesFor !== q ? "looking…" : "no files match", sub: "" });
        return out;
    }

    function appResults(q) {
        const t = q.trim();
        const ql = t.toLowerCase();
        const out = [];

        if (t.startsWith("?")) {
            const w = t.slice(1).trim();
            return w ? [webRow(w)]
                     : [{ kind: "hint", glyph: "󰖟", title: "search the web", plain: true,
                          sub: Object.keys(shell.engines).map(k => "?" + k + " " + shell.engines[k].name).join("   ") }];
        }
        if (t.startsWith("+")) return todoResults(t.slice(1));
        if (t.startsWith(":")) return emojiResults(t.slice(1));
        if (t.startsWith("/")) return fileResults(t);

        const conv = tryConvert(t);
        const calc = conv ? null : tryCalc(t);
        if (conv)
            out.push({ kind: "calc", glyph: "󰃬", title: "= " + conv.value + (conv.unit ? " " + conv.unit : ""), plain: true,
                       sub: conv.sub + "   ·   ⏎ copies the result", value: conv.value });
        else if (calc !== null)
            out.push({ kind: "calc", glyph: "󰃬", title: "= " + calc, plain: true,
                       sub: t.replace(/^=\s*/, "") + "   ·   ⏎ copies the result", value: calc });

        if (!ql) {
            const ranked = shell.apps.filter(a => !isHidden(a.id)).map(a => ({ a: a, f: frecency(a.id) }));
            ranked.sort((x, y) => (y.f - x.f) || x.a._n.localeCompare(y.a._n));
            for (const r of ranked) out.push(appRow(r.a, r.f > 0));
            return out;
        }

        const scored = [];
        for (const a of shell.apps) {
            const n = fuzzy(ql, a._n);
            const g = fuzzy(ql, a._g);
            const k = a._k.indexOf(ql) >= 0 ? 600 : -1;           // keywords / comment: substring only
            const c = ql.length >= 3 && a._c.indexOf(ql) >= 0 ? 450 : -1;
            const i = fuzzy(ql, a._i);
            const best = Math.max(n, g >= 0 ? g * 0.7 : -1, k, c, i >= 0 ? i * 0.5 : -1);
            if (best < 0) continue;
            scored.push({ a: a, s: best + Math.min(80, frecency(a.id) * 6) + (isPinned(a.id) ? 25 : 0) - (isHidden(a.id) ? 120 : 0) });
        }
        scored.sort((x, y) => y.s - x.s);
        for (const r of scored) out.push(appRow(r.a, false));

        // never a dead end: the query can always run or go to the web
        if (calc === null && !conv) {
            out.push({ kind: "run", glyph: "󰆍", title: "run  " + t, plain: true, cmd: t,
                       sub: "as a shell command   ·   ⇧⏎ in a terminal" });
            out.push(webRow(t));
        }
        return out;
    }

    function actionResults(q) {
        const a = shell.subApp;
        const ql = q.trim().toLowerCase();
        const items = [{ kind: "action", app: a, act: null, title: "open " + a.name,
                         sub: a.terminal ? "in a terminal" : "default", icon: iconFor(a.icon) }];
        for (const x of a.actions)
            items.push({ kind: "action", app: a, act: x, title: x.name, sub: a.name,
                         icon: iconFor(x.icon) || iconFor(a.icon), glyph: "󰅂" });
        items.push({ kind: "pin", app: a, glyph: "󰐃", plain: true, badge: "^S",
                     title: isPinned(a.id) ? "unpin from favourites" : "pin to favourites", sub: "the strip above the list" });
        items.push({ kind: "hide", app: a, glyph: isHidden(a.id) ? "\u{F0208}" : "\u{F0209}", plain: true, badge: "^H",
                     title: isHidden(a.id) ? "show in the app list again" : "hide from the app list",
                     sub: isHidden(a.id) ? "it's hidden: only a search finds it" : "a search still finds it" });
        return ql ? items.filter(it => fuzzy(ql, it.title.toLowerCase()) >= 0) : items;
    }

    function windowResults(q) {
        const words = q.trim().toLowerCase().split(/\s+/).filter(w => w);
        const out = [];
        for (const w of shell.wins) {
            if (words.some(x => w._t.indexOf(x) < 0)) continue;
            out.push({ kind: "win", win: w, title: w.title, icon: iconForClass(w.cls), glyph: "󰖯",
                       sub: w.cls + (w.flags ? "   ·   " + w.flags : ""), badge: w.ws });
        }
        return out;
    }

    function runResults(q) {
        const t = q.trim();
        const tl = t.toLowerCase();
        const out = [];
        if (t)
            out.push({ kind: "run", glyph: "󰆍", title: t, plain: true, cmd: t,
                       sub: "run   ·   ⇧⏎ in a terminal" });
        for (const c of shell.usage.runs) {
            if (c === t) continue;
            if (tl && fuzzy(tl, c.toLowerCase()) < 0) continue;
            out.push({ kind: "run", glyph: "󰋚", title: c, cmd: c, sub: "history", complete: true });
            if (out.length > 30) break;
        }
        if (t && !/\s/.test(t)) {
            let n = 0;
            for (const b of shell.bins) {
                if (b === t || !b.startsWith(t)) continue;
                out.push({ kind: "run", glyph: "󰞷", title: b, cmd: b, sub: "command", complete: true });
                if (++n >= 40) break;
            }
        }
        return out;
    }

    function clipResults(q) {
        const words = q.trim().toLowerCase().split(/\s+/).filter(w => w);
        const out = [];
        for (const c of shell.clips) {
            if (words.some(w => c._t.indexOf(w) < 0)) continue;
            out.push({ kind: "clip", clip: c, glyph: c.image ? "󰥶" : "󰧭",
                       title: c.text.length > 160 ? c.text.slice(0, 160) + "…" : c.text,
                       sub: c.size, badge: "#" + c.id });
        }
        return out;
    }

    function sessionResults(q) {
        const ql = q.trim().toLowerCase();
        const idle = shell.idleOn
            ? { key: "idle", glyph: "󰅶", title: "idle mode  ·  on",
                sub: "locks after " + shell.idleLockMin + " min idle   ·   ⏎ stay awake instead", stay: true }
            : { key: "idle", glyph: "󰛊", title: "idle mode  ·  off",
                sub: "never locks   ·   ⏎ lock after " + shell.idleLockMin + " min idle", stay: true };
        const items = [
            { key: "lock",     glyph: "󰌾", title: "lock",      sub: "hyprlock",            cmd: "loginctl lock-session" },
            idle,
            { key: "suspend",  glyph: "󰤄", title: "suspend",   sub: "sleep · locks first", cmd: "systemctl suspend" },
            { key: "logout",   glyph: "󰗽", title: "log out",   sub: "end the hyprland session", cmd: "hyprctl dispatch exit", confirm: true },
            { key: "reboot",   glyph: "󰜉", title: "reboot",    sub: "restart the machine", cmd: "systemctl reboot", confirm: true },
            { key: "poweroff", glyph: "󰐥", title: "shut down", sub: "power off",           cmd: "systemctl poweroff", confirm: true, tint: Theme.t.crit }
        ];
        const out = [];
        for (const it of items) {
            if (ql && fuzzy(ql, it.title.toLowerCase()) < 0 && fuzzy(ql, it.key) < 0) continue;
            it.kind = "session";
            out.push(it);
        }
        return out;
    }

    function refresh(keepIndex) {
        const prev = list.currentIndex;
        let r = [];
        switch (shell.mode) {
        case "apps":    r = shell.subApp ? actionResults(shell.query) : appResults(shell.query); break;
        case "windows": r = windowResults(shell.query); break;
        case "run":     r = runResults(shell.query); break;
        case "clip":    r = clipResults(shell.query); break;
        case "session": r = sessionResults(shell.query); break;
        case "theme":   r = []; break;
        }
        shell.armed = -1;
        shell.results = r;
        select(r.length ? (keepIndex ? Math.min(Math.max(prev, 0), r.length - 1) : 0) : -1);
    }

    function select(i) {
        list.currentIndex = i;
        if (i >= 0) list.positionViewAtIndex(i, ListView.Contain);
        if (shell.mode === "clip") previewTimer.restart();
    }

    // ── navigation ───────────────────────────────────────────────
    function setMode(m) {
        if (!shell.modeDefs.some(d => d.key === m)) m = "apps";
        if (m === "clip") { shell.clipsLoading = true; clipProc.running = true; }
        shell.wipeArmed = false;
        if (m === "windows") winProc.running = true;
        if (m === "run" && !shell.bins.length) binsProc.running = true;
        if (m === "session") idleFile.reload();
        if (m === "theme") picker.reset();
        shell.subApp = null;
        shell.subPrev = null;
        shell.previewFor = "";
        shell.previewImage = "";
        shell.previewText = "";
        shell.mode = m;
        search.text = "";
        shell.query = "";
        refresh(false);
    }

    function cycleMode(d) {
        const keys = shell.modeDefs.map(m => m.key);
        setMode(keys[(keys.indexOf(shell.mode) + d + keys.length) % keys.length]);
    }

    function move(d) {
        const n = shell.results.length;
        if (!n) return;
        let i = list.currentIndex + d;
        i = Math.abs(d) === 1 ? (i + n) % n : Math.max(0, Math.min(n - 1, i));
        shell.armed = -1;
        select(i);
    }

    function onTyped(text) {
        if (shell.mode === "theme") { picker.query = text; return; }
        // ">" from the apps view jumps straight into run mode
        if (shell.mode === "apps" && !shell.subApp && text.startsWith(">")) {
            setMode("run");
            search.text = text.slice(1).trimStart();
            return;
        }
        shell.query = text;
        refresh(false);
    }

    function enterActions() {
        const r = shell.results[list.currentIndex];
        if (shell.mode !== "apps" || shell.subApp || !r || r.kind !== "app")
            return false;
        shell.subPrev = { query: search.text, index: list.currentIndex };
        shell.subApp = r.app;
        search.text = "";
        refresh(false);
        return true;
    }

    function exitActions() {
        if (!shell.subApp) return false;
        const p = shell.subPrev || { query: "", index: 0 };
        shell.subApp = null;
        shell.subPrev = null;
        search.text = p.query;
        refresh(false);
        select(Math.min(p.index, shell.results.length - 1));
        return true;
    }

    // ── actions ──────────────────────────────────────────────────
    function sh(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    function launchApp(a, alt) {
        bumpApp(a.id);
        if (a.terminal || alt) Quickshell.execDetached([shell.terminal, "-e"].concat(Array.from(a.entry.command)));
        else a.entry.execute();
        updateFavs();
        hide();
    }

    function launchFav(i) {
        const f = shell.favs[i];
        if (f) launchApp(f.app, false);
    }

    function activate(i, alt) {
        const r = shell.results[i];
        if (!r) return;
        switch (r.kind) {
        case "app":
            launchApp(r.app, alt);
            break;
        case "action":
            if (r.act) {
                bumpApp(r.app.id);
                r.act.execute();
                hide();
            } else {
                launchApp(r.app, alt);
            }
            break;
        case "win":
            Hyprland.dispatch("focuswindow address:" + r.win.addr);
            hide();
            break;
        case "calc":
            Quickshell.execDetached(["wl-copy", r.value]);
            hide();
            break;
        case "todo":
            Todo.add(r.text);
            hide();
            break;
        case "emoji":
            rememberEmoji(r.char);
            Quickshell.execDetached(["wl-copy", r.char]);
            hide();
            break;
        case "file":
            if (alt) Quickshell.execDetached(["dolphin", "--select", r.file.path]);
            else Quickshell.execDetached(["xdg-open", r.file.path]);
            hide();
            break;
        case "pin":
            togglePin(r.app.id);
            break;
        case "hide":
            toggleHidden(r.app.id);
            break;
        case "hint":
            break;
        case "web":
            Quickshell.execDetached(["xdg-open", r.url]);
            hide();
            break;
        case "run":
            rememberRun(r.cmd);
            if (alt) Quickshell.execDetached([shell.terminal, "--hold", "sh", "-c", r.cmd]);
            else sh(r.cmd);
            hide();
            break;
        case "clip":
            Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy",
                                     "clip", r.clip.line]);
            hide();
            break;
        case "session":
            if (r.key === "idle") {
                sh("~/.config/hypr/scripts/idle.sh toggle");
                setIdle(!shell.idleOn);                 // move now, the file watch confirms
                return;
            }
            if (r.confirm && shell.armed !== i) {       // destructive: ⏎ twice
                shell.armed = i;
                return;
            }
            hide();
            sh(r.cmd);
            break;
        }
    }

    // shift+delete: forget a clip / close a window
    function removeAt(i) {
        const r = shell.results[i];
        if (!r) return;
        if (r.kind === "clip") {
            Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "clip", r.clip.line]);
            shell.clips = shell.clips.filter(c => c !== r.clip);
        } else if (r.kind === "win") {
            Hyprland.dispatch("closewindow address:" + r.win.addr);
            shell.wins = shell.wins.filter(w => w !== r.win);
        } else {
            return;
        }
        shell.previewFor = "";
        refresh(true);
    }

    // clear the whole clipboard history: first press arms, the second wipes
    Timer { id: wipeDisarm; interval: 4000; onTriggered: shell.wipeArmed = false }
    function wipeClips() {
        if (!shell.clips.length) return;
        if (!shell.wipeArmed) {
            shell.wipeArmed = true;
            wipeDisarm.restart();
            return;
        }
        shell.wipeArmed = false;
        Quickshell.execDetached(["cliphist", "wipe"]);
        shell.clips = [];
        shell.previewFor = "";
        shell.previewText = "";
        shell.previewImage = "";
        refresh(false);
    }

    function complete() {
        const r = shell.results[list.currentIndex];
        if (shell.mode !== "run" || !r || !r.complete) return false;
        search.text = r.cmd + (r.sub === "command" ? " " : "");
        search.cursorPosition = search.text.length;
        return true;
    }

    function handleKey(ev) {
        const ctrl = ev.modifiers & Qt.ControlModifier;
        const shift = ev.modifiers & Qt.ShiftModifier;
        const altKey = ev.modifiers & Qt.AltModifier;
        const atEnd = search.cursorPosition === search.text.length;
        let done = true;

        // theme tab: typing searches; arrows/⏎ drive the cards; ctrl+l/m/t/c toggle
        if (shell.mode === "theme" && !altKey) {
            const nav = [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down, Qt.Key_Return, Qt.Key_Enter].indexOf(ev.key) >= 0;
            const chord = ctrl && [Qt.Key_L, Qt.Key_M, Qt.Key_T, Qt.Key_C, Qt.Key_E].indexOf(ev.key) >= 0;
            if (nav || chord) {
                picker.handleKey(ev);
                ev.accepted = true;
                return;
            }
        }

        if (ev.key === Qt.Key_Control) {
            shell.ctrlHeld = true;
            done = false;
        } else if (altKey && ev.key >= Qt.Key_1 && ev.key < Qt.Key_1 + shell.modeDefs.length) {
            setMode(shell.modeDefs[ev.key - Qt.Key_1].key);
        } else if (ctrl && ev.key >= Qt.Key_1 && ev.key <= Qt.Key_9) {
            launchFav(ev.key - Qt.Key_1);
        } else switch (ev.key) {
        case Qt.Key_Escape:   if (!exitActions()) hide(); break;
        case Qt.Key_Down:     move(1); break;
        case Qt.Key_Up:       move(-1); break;
        case Qt.Key_PageDown: move(6); break;
        case Qt.Key_PageUp:   move(-6); break;
        case Qt.Key_Tab:      cycleMode(1); break;
        case Qt.Key_Backtab:  cycleMode(-1); break;
        case Qt.Key_Return:
        case Qt.Key_Enter:    activate(list.currentIndex, shift); break;
        case Qt.Key_J: case Qt.Key_N:
            if (ctrl) move(1); else done = false;
            break;
        case Qt.Key_K: case Qt.Key_P:
            if (ctrl) move(-1); else done = false;
            break;
        case Qt.Key_S: {
            const r = shell.results[list.currentIndex];
            if (ctrl && r && (r.kind === "app" || r.kind === "action")) togglePin(r.app.id);
            else done = false;
            break;
        }
        case Qt.Key_H: {
            const r = shell.results[list.currentIndex];
            if (ctrl && r && (r.kind === "app" || r.kind === "action")) toggleHidden(r.app.id);
            else done = false;
            break;
        }
        case Qt.Key_Delete:
            if (ctrl && shift && shell.mode === "clip") wipeClips();
            else if (shift) removeAt(list.currentIndex);
            else done = false;
            break;
        case Qt.Key_Right:
            done = atEnd && (complete() || enterActions());
            break;
        case Qt.Key_Left:
            done = search.cursorPosition === 0 && exitActions();
            break;
        case Qt.Key_Backspace:
            if (search.text !== "") done = false;
            else if (!exitActions() && shell.mode !== "apps") setMode("apps");
            break;
        default:
            done = false;
        }
        ev.accepted = done;
    }

    // ── open / close ─────────────────────────────────────────────
    function show(m) {
        Theme.reload();
        const mon = Hyprland.focusedMonitor;
        shell.targetScreen = Quickshell.screens.find(s => mon && s.name === mon.name) || Quickshell.screens[0];
        if (!shell.apps.length) reindex();
        else updateFavs();
        shell.ctrlHeld = false;
        shell.pointer = Qt.point(-1, -1);
        setMode(m || "apps");
        shell.shown = true;
        openAnim.restart();
        search.forceActiveFocus();
    }

    function hide() {
        Theme.previewId = "";                       // a look tried on but not kept goes away
        shell.shown = false;
        shell.armed = -1;
        shell.wipeArmed = false;
        shell.ctrlHeld = false;
        shell.previewFor = "";
        shell.previewImage = "";
        shell.previewText = "";
        Quickshell.execDetached(["sh", "-c", 'rm -f "$1"/clip-*', "clean", shell.runDir]);
    }

    IpcHandler {
        target: "launcher"
        function toggle(mode: string): void {
            if (shell.shown && (mode === "" || mode === shell.mode)) shell.hide();
            else shell.show(mode);
        }
        function open(mode: string): void { shell.show(mode); }
        function close(): void { shell.hide(); }
        // the theme tab, aimed at a widget — waybar's 󰏘 button uses this
        function themeFor(target: string): void {
            if (shell.shown && shell.mode === "theme" && picker.target === target) { shell.hide(); return; }
            shell.show("theme");
            picker.target = target || "launcher";
        }
        // open with text already typed, e.g. `… call launcher prefill apps "=2^10"`
        function prefill(mode: string, text: string): void {
            shell.show(mode);
            search.text = text;
            search.cursorPosition = search.text.length;
        }
    }

    // waybar can't run qml — this daemon renders its theme to css
    ThemeExport {}

    Component.onCompleted: {
        Theme.widget = "launcher";
        Quickshell.execDetached(["mkdir", "-p", shell.stateDir]);
        binsProc.running = true;
    }

    // ══ the window ═══════════════════════════════════════════════
    // sized to the panel (not the whole screen): the compositor only
    // re-blurs this patch when the glass animates. clicks elsewhere
    // clear the hyprland focus grab, which closes the launcher.
    readonly property var th: Theme.t
    readonly property int margin: 44                // room for the shadow and the pop-in
    readonly property int panelMaxW: 960
    readonly property int panelH: 580

    PanelWindow {
        id: win
        visible: shell.shown
        screen: shell.targetScreen

        anchors.top: true
        margins.top: Math.max(0, Math.round((screen ? screen.height : 1080) * 0.14) - shell.margin)
        implicitWidth: shell.panelMaxW + shell.margin * 2
        implicitHeight: shell.panelH + shell.margin * 2
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: if (visible) search.forceActiveFocus()

        MouseArea { anchors.fill: parent; onClicked: shell.hide() }

        ThemedPanel {
            id: panel
            title: "launcher"
            animate: shell.shown
            width: Math.min(shell.mode === "clip" ? shell.panelMaxW : 720, parent.width - shell.margin * 2)
            height: shell.panelH
            x: Math.round((parent.width - width) / 2)
            y: shell.margin + slide
            property real slide: 0
            Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }

            ParallelAnimation {
                id: openAnim
                NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { target: panel; property: "scale"; from: 0.96; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                NumberAnimation { target: panel; property: "slide"; from: -14; to: 0; duration: 320; easing.type: Easing.OutQuint }
            }

            MouseArea { anchors.fill: parent }             // swallow clicks

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                anchors.topMargin: 16 + panel.topInset
                spacing: 12

                // ── emblem + search ──────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Emblem { glyph: shell.subApp ? "󰅂" : shell.modeDef.glyph }

                    Field {
                        Layout.fillWidth: true
                        implicitHeight: 44
                        focused: search.activeFocus

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 16
                            spacing: 10

                            // breadcrumb while browsing an app's actions
                            Item {
                                visible: shell.subApp !== null
                                implicitWidth: crumbRow.implicitWidth + 18
                                implicitHeight: 26
                                Surface { anchors.fill: parent; radius: shell.th.pillFull ? 13 : shell.th.radiusSm; strength: 0.85 }
                                Row {
                                    id: crumbRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Image {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16; height: 16
                                        source: shell.subApp ? shell.iconFor(shell.subApp.icon) : ""
                                        sourceSize: Qt.size(32, 32)
                                        visible: String(source) !== ""
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (shell.subApp ? shell.subApp.name : "") + "  󰅂"
                                        color: shell.th.selText
                                        font { family: shell.th.font; pixelSize: 12 }
                                    }
                                }
                            }

                            Text {                                   // phosphor prompt
                                visible: shell.th.surface === "block"
                                text: "❯"
                                color: shell.th.ink
                                font { family: shell.th.font; pixelSize: 16; bold: true }
                            }

                            TextInput {
                                id: search
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                color: shell.th.text
                                selectionColor: Theme.alpha(shell.th.accent, 0.45)
                                selectedTextColor: shell.th.selText
                                font { family: shell.th.font; pixelSize: 16 }
                                clip: true
                                focus: true
                                onTextChanged: shell.onTyped(text)
                                Keys.onPressed: (ev) => shell.handleKey(ev)
                                Keys.onReleased: (ev) => { if (ev.key === Qt.Key_Control) shell.ctrlHeld = false; }

                                cursorDelegate: Rectangle {
                                    width: shell.th.surface === "block" ? 9 : 2
                                    color: shell.th.match
                                    opacity: 0.85
                                    visible: search.activeFocus && shell.mode !== "theme"
                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        running: search.activeFocus && shell.shown
                                        NumberAnimation { to: 0.1; duration: 530; easing.type: Easing.InOutQuad }
                                        NumberAnimation { to: 0.85; duration: 530; easing.type: Easing.InOutQuad }
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: search.text === ""
                                    text: shell.subApp ? "pick an action…" : shell.modeDef.hint
                                    color: shell.th.faint
                                    font { family: shell.th.font; pixelSize: 15; italic: true }
                                }
                            }

                            Text {
                                visible: (shell.mode === "clip" && shell.clipsLoading) || (shell.mode === "windows" && winProc.running)
                                text: "…"
                                color: shell.th.dim
                                font { family: shell.th.font; pixelSize: 14 }
                            }
                        }
                    }
                }

                // ── mode tabs ────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    TabBar {
                        model: shell.modeDefs
                        current: shell.mode
                        onPicked: (key) => { shell.setMode(key); search.forceActiveFocus(); }
                    }

                    Item { Layout.fillWidth: true }

                    Item {                                   // clipboard: clear all (click twice)
                        visible: shell.mode === "clip" && shell.clips.length > 0
                        implicitWidth: wipeRow.implicitWidth + 16
                        implicitHeight: 22
                        Surface {
                            anchors.fill: parent
                            radius: shell.th.pillFull ? height / 2 : shell.th.radiusSm
                            tint: shell.th.crit
                            strength: shell.wipeArmed ? 1 : wipeHover.hovered ? 0.35 : 0
                        }
                        Row {
                            id: wipeRow
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\u{F0A7A}"
                                color: shell.wipeArmed ? shell.th.selText : shell.th.critInk
                                font { family: shell.th.glyphFont; pixelSize: 12 }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: shell.wipeArmed ? "click again to clear all " + shell.clips.length : "clear all"
                                color: shell.wipeArmed ? shell.th.selText : shell.th.critInk
                                font { family: shell.th.font; pixelSize: 11; bold: shell.wipeArmed }
                            }
                        }
                        HoverHandler { id: wipeHover }
                        TapHandler { onTapped: { shell.wipeClips(); search.forceActiveFocus(); } }
                    }

                    Text {
                        readonly property string lead: shell.mode === "apps" && !shell.subApp ? shell.query.trim()[0] || "" : ""
                        readonly property string kind: lead === ":" ? "emoji" : lead === "/" ? "file" : lead === "+" || lead === "?" ? "" : "app"
                        visible: shell.mode !== "session" && shell.mode !== "theme" && !(shell.mode === "apps" && kind === "")
                        readonly property int n: shell.mode === "apps" && !shell.subApp
                                                 ? shell.results.filter(r => r.kind === kind).length
                                                 : shell.results.length
                        readonly property string noun: shell.mode === "apps" ? (shell.subApp ? "action" : kind)
                                                     : shell.mode === "clip" ? "item"
                                                     : shell.mode === "windows" ? "window" : "match"
                        text: n + " " + noun + (n === 1 || noun === "emoji" ? "" : noun === "match" ? "es" : "s")
                        color: shell.th.faint
                        font { family: shell.th.font; pixelSize: 11 }
                    }
                }

                // ── the well: favourites, results, preview / themes ──
                Well {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        // ── favourites ───────────────────────────
                        Item {
                            id: favStrip
                            visible: shell.mode === "apps" && !shell.subApp && shell.query === "" && shell.favs.length > 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 104

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 6
                                spacing: 8

                                Repeater {
                                    model: shell.favs
                                    delegate: Item {
                                        id: fav
                                        required property var modelData
                                        required property int index
                                        readonly property bool hot: favHover.hovered
                                        width: 80
                                        height: 94

                                        IconTile {
                                            id: favTile
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: 2
                                            icon: fav.modelData.icon || ""
                                            hot: fav.hot
                                            scale: fav.hot ? 1.1 : 1
                                            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                                            Item {                       // ctrl+N badge while ctrl is held
                                                visible: shell.ctrlHeld
                                                width: 20
                                                height: 20
                                                x: parent.width - 16
                                                y: -4
                                                Surface { anchors.fill: parent; radius: shell.th.surface === "block" ? 2 : 10 }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: fav.index + 1
                                                    color: shell.th.selText
                                                    font { family: shell.th.font; pixelSize: 11; bold: true }
                                                }
                                            }
                                        }

                                        Text {
                                            anchors.top: favTile.bottom
                                            anchors.topMargin: 8
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            text: (fav.modelData.pinned ? "󰐃 " : "") + fav.modelData.app.name
                                            elide: Text.ElideRight
                                            color: fav.hot ? shell.th.text : shell.th.dim
                                            font { family: shell.th.font; pixelSize: 10 }
                                        }

                                        HoverHandler { id: favHover }
                                        TapHandler {
                                            acceptedButtons: Qt.LeftButton
                                            onTapped: shell.launchApp(fav.modelData.app, false)
                                        }
                                        TapHandler {
                                            acceptedButtons: Qt.RightButton
                                            onTapped: shell.togglePin(fav.modelData.app.id)
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width * 0.86
                                height: 1
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 0.5; color: Theme.alpha(shell.th.text, 0.2) }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                            }
                        }

                        // ── theme tab ────────────────────────────
                        ThemePicker {
                            id: picker
                            keyPrefix: "^"
                            visible: shell.mode === "theme"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: 4
                        }

                        RowLayout {
                            visible: shell.mode !== "theme"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8

                            // ── results ──────────────────────────
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                ListView {
                                    id: list
                                    anchors.fill: parent
                                    clip: true
                                    model: shell.results
                                    spacing: 2
                                    boundsBehavior: Flickable.StopAtBounds
                                    highlightFollowsCurrentItem: true
                                    highlightMoveDuration: 110
                                    highlightResizeDuration: 0

                                    highlight: Surface {
                                        strength: 1
                                        tick: true
                                    }

                                    delegate: Item {
                                        id: row
                                        required property var modelData
                                        required property int index
                                        readonly property bool sel: ListView.isCurrentItem
                                        readonly property bool hot: shell.armed === index
                                        readonly property color tint: hot ? shell.th.crit : (modelData.tint || shell.th.accent)
                                        readonly property bool lit: sel || hot
                                        width: ListView.view.width
                                        height: 50

                                        Surface {                            // armed (confirm) state
                                            anchors.fill: parent
                                            visible: row.hot
                                            tint: shell.th.crit
                                            tick: true
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 14
                                            spacing: 12

                                            // icon — theme icon, else a glyph tile
                                            Item {
                                                implicitWidth: 34
                                                implicitHeight: 34
                                                Surface {
                                                    anchors.fill: parent
                                                    visible: !appIcon.visible
                                                    radius: Math.min(9, shell.th.radiusSm)
                                                    tint: row.tint
                                                    strength: row.lit ? 0.95 : 0.55
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: !appIcon.visible
                                                    text: row.modelData.glyph || "󰣆"
                                                    color: shell.th.surface === "gloss" || shell.th.surface === "gradient" ? "white"
                                                         : row.lit && shell.th.surface === "block" ? shell.th.selText
                                                         : row.tint
                                                    font { family: shell.th.glyphFont; pixelSize: row.modelData.emoji ? 21 : 17 }
                                                    style: shell.th.raisedText ? Text.Raised : Text.Normal
                                                    styleColor: Theme.alpha(Qt.darker(row.tint, 2.2), 0.6)
                                                }
                                                Image {
                                                    id: appIcon
                                                    anchors.centerIn: parent
                                                    width: 30
                                                    height: 30
                                                    source: row.modelData.icon || ""
                                                    sourceSize: Qt.size(60, 60)
                                                    asynchronous: true
                                                    smooth: true
                                                    mipmap: true
                                                    visible: String(source) !== "" && status === Image.Ready
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: row.modelData.plain
                                                          ? shell.esc(row.modelData.title)
                                                          : shell.highlight(row.modelData.title, shell.query,
                                                                            row.lit ? String(shell.th.selText) : String(shell.th.match))
                                                    textFormat: Text.StyledText
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                    color: row.lit ? shell.th.selText : Theme.alpha(shell.th.text, 0.88)
                                                    style: row.lit && shell.th.raisedText ? Text.Raised : Text.Normal
                                                    styleColor: Theme.alpha(Qt.darker(row.tint, 2.4), 0.55)
                                                    font { family: shell.th.font; pixelSize: 14 }
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    visible: text !== ""
                                                    text: row.hot ? "press ⏎ again to " + row.modelData.title + "   ·   ↑↓ to cancel"
                                                                  : (row.modelData.sub || "")
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                    color: row.lit ? shell.th.selDim : shell.th.faint
                                                    font { family: shell.th.font; pixelSize: 11 }
                                                }
                                            }

                                            Text {                           // right badge
                                                text: row.sel ? (row.hot ? "⏎ ⏎"
                                                                 : row.modelData.kind === "app" ? "→ 󰅂   ⏎"
                                                                 : row.modelData.kind === "hint" ? "" : "⏎")
                                                              : (row.modelData.badge || "")
                                                color: row.lit ? shell.th.selText : shell.th.faint
                                                font { family: shell.th.glyphFont; pixelSize: row.sel ? 13 : 11 }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                            // follow the pointer only when it really moves: rows
                                            // sliding under a resting cursor (typing, scrolling)
                                            // report hover too, at the same scene position
                                            onPositionChanged: (m) => {
                                                const p = mapToItem(null, m.x, m.y);
                                                const moved = Math.abs(p.x - shell.pointer.x) + Math.abs(p.y - shell.pointer.y) > 1;
                                                const first = shell.pointer.x < 0;
                                                shell.pointer = p;
                                                if (!moved || first || list.currentIndex === row.index) return;
                                                shell.armed = -1;
                                                shell.select(row.index);
                                            }
                                            onClicked: (m) => {
                                                shell.select(row.index);
                                                const k = row.modelData.kind;
                                                if (m.button === Qt.MiddleButton) shell.removeAt(row.index);
                                                else if (m.button === Qt.RightButton && (k === "app" || k === "action"))
                                                    shell.togglePin(row.modelData.app.id);
                                                else shell.activate(row.index, m.button === Qt.RightButton
                                                                                || (m.modifiers & Qt.ShiftModifier));
                                                search.forceActiveFocus();
                                            }
                                        }
                                    }
                                }

                                // empty states
                                Column {
                                    anchors.centerIn: parent
                                    visible: shell.results.length === 0
                                    spacing: 12
                                    Emblem {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        glyph: shell.mode === "clip" ? "󰅌" : shell.mode === "run" ? "󰆍"
                                             : shell.mode === "windows" ? "󰖯" : "󰍉"
                                        opacity: 0.75
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: shell.mode === "clip"
                                            ? (shell.clipsLoading ? "reading history…"
                                               : shell.query ? "nothing in the history matches" : "clipboard history is empty")
                                            : shell.mode === "run" ? "type a command — history and $PATH show up here"
                                            : shell.mode === "windows" ? (winProc.running ? "looking…" : "no windows match")
                                            : "nothing matches"
                                        color: shell.th.faint
                                        font { family: shell.th.font; pixelSize: 13; italic: true }
                                    }
                                }
                            }

                            // ── clipboard preview ────────────────
                            Rectangle {
                                visible: shell.mode === "clip"
                                Layout.preferredWidth: 300
                                Layout.fillHeight: true
                                radius: shell.th.radiusSm
                                color: Theme.alpha(shell.th.text, 0.05)
                                border.width: 1
                                border.color: Theme.alpha(shell.th.text, 0.10)

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: "󰛐"
                                            color: shell.th.ink
                                            font { family: shell.th.glyphFont; pixelSize: 14 }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: "preview"
                                            color: shell.th.text
                                            font { family: shell.th.font; pixelSize: 12 }
                                        }
                                        Text {
                                            readonly property var cur: shell.results[list.currentIndex]
                                            text: cur && cur.kind === "clip" ? cur.clip.size : ""
                                            color: shell.th.faint
                                            font { family: shell.th.font; pixelSize: 10 }
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true

                                        Image {
                                            id: prevImg
                                            anchors.fill: parent
                                            source: shell.previewImage
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            cache: false
                                            smooth: true
                                            mipmap: true
                                            visible: shell.previewImage !== "" && status === Image.Ready
                                        }
                                        Text {
                                            anchors.fill: parent
                                            visible: shell.previewImage === "" && shell.previewText !== ""
                                            text: shell.previewText
                                            textFormat: Text.PlainText
                                            wrapMode: Text.WrapAnywhere
                                            elide: Text.ElideRight
                                            color: Theme.alpha(shell.th.text, 0.88)
                                            font { family: shell.th.font; pixelSize: 11 }
                                            lineHeight: 1.15
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: !prevImg.visible && shell.previewText === ""
                                            text: shell.results.length ? "…" : ""
                                            color: shell.th.faint
                                            font { family: shell.th.font; pixelSize: 14 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── footer · keycaps ─────────────────────────────
                // a clipped strip: wide fonts cut the hints off instead
                // of pushing the panel wider
                RowLayout {
                    id: footer
                    Layout.fillWidth: true
                    spacing: 14

                    readonly property var cur: shell.results[list.currentIndex] || null
                    readonly property string kind: cur ? cur.kind : ""

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: keyRow.implicitHeight
                        clip: true
                        Row {
                            id: keyRow
                            spacing: 14
                            readonly property string kind: footer.kind
                            Keycap { visible: shell.mode !== "theme"; keys: "↑↓"; label: "move" }
                            Keycap {
                                visible: shell.mode !== "theme" && keyRow.kind !== "hint"
                                keys: "⏎"
                                label: keyRow.kind === "calc" || keyRow.kind === "emoji" || shell.mode === "clip" ? "copy"
                                     : keyRow.kind === "todo" ? "add" : shell.mode === "run" ? "run"
                                     : shell.mode === "windows" ? "focus" : shell.mode === "session" ? "select" : "open"
                            }
                            Keycap { visible: keyRow.kind === "app"; keys: "→"; label: "actions" }
                            Keycap { visible: shell.subApp !== null; keys: "←"; label: "back" }
                            Keycap { visible: keyRow.kind === "app" || keyRow.kind === "action"; keys: "^S"; label: "pin" }
                            Keycap { visible: favStrip.visible; keys: "^1-" + shell.favs.length; label: "favourite" }
                            Keycap { visible: keyRow.kind === "file"; keys: "⇧⏎"; label: "show in folder" }
                            Keycap { visible: shell.mode === "run"; keys: "⇧⏎"; label: "terminal" }
                            Keycap { visible: shell.mode === "run"; keys: "→"; label: "complete" }
                            Keycap { visible: shell.mode === "clip"; keys: "⇧del"; label: "remove" }
                            Keycap {
                                visible: shell.mode === "clip" && shell.clips.length > 0
                                keys: "^⇧del"
                                label: shell.wipeArmed ? "again to clear all" : "clear all"
                            }
                            Keycap { visible: shell.mode === "windows"; keys: "⇧del"; label: "close" }
                            Keycap { visible: shell.mode === "theme"; keys: "←→↑↓"; label: "try on" }
                            Keycap { visible: shell.mode === "theme"; keys: "⏎"; label: "keep" }
                            Keycap { visible: shell.mode === "theme"; keys: "^L"; label: "link" }
                            Keycap { visible: shell.mode === "theme"; keys: "^M"; label: "motion" }
                            Keycap { visible: shell.mode === "theme"; keys: "^T"; label: "target" }
                            Keycap { visible: shell.mode === "theme"; keys: "^E"; label: "studio" }
                            Keycap { keys: "tab"; label: "mode" }
                        }
                    }
                    Keycap { keys: "esc"; label: shell.subApp ? "back" : "close" }
                }
            }
        }
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.visible
        onCleared: shell.hide()
    }
}
