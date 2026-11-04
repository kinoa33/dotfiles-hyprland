// ╔══════════════════════════════════════════════════════════════╗
// ║  theme studio · make and change the looks every widget wears ║
// ║  open: Super+Shift+T, or "studio" in any widget's theme tab  ║
// ║        (hypr/scripts/theme-studio.sh [theme] [widget])       ║
// ║                                                              ║
// ║  left    every theme — new · copy · delete / reset           ║
// ║  middle  the theme on stand-ins of every widget, over your   ║
// ║          wallpaper (or plain dark / light)                   ║
// ║  right   the inspector: name, surfaces, details, shape,      ║
// ║          type, every colour as a recipe over the palette,    ║
// ║          and readability. "editing for" picks the whole      ║
// ║          theme or one widget (per-widget overrides)          ║
// ║                                                              ║
// ║  edits show here at once; with "live" on they also show on   ║
// ║  the real widgets (bar, notifications, launcher …) wearing   ║
// ║  the theme, unsaved, until you save (^S) or discard.         ║
// ║  themes are saved to ~/.config/quickshell/user-themes.json   ║
// ║  (format: common/themes/README.md)                           ║
// ╚══════════════════════════════════════════════════════════════╝
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "common"
import "studio"

ShellRoot {
    id: app

    // ══ the editor: one theme, held as a spec, edited immutably ═══
    QtObject {
        id: ed

        property string themeId: ""
        property var spec: ({ id: "", style: {}, colors: {} })
        property string saved: ""                   // the spec as last saved (json)
        property string scope: ""                   // "" = the whole theme, else a widget key
        property string openColor: ""               // which colour's editor is open
        property bool live: true                    // show unsaved edits on the real widgets
        property var undoStack: []
        property var redoStack: []
        property string lastKey: ""
        property real lastTime: 0

        readonly property bool dirty: JSON.stringify(spec) !== saved
        readonly property bool builtin: Theme.isBuiltin(themeId)
        readonly property var baseline: Theme.builtinSpecOf(themeId)   // built-ins: what "reset" goes back to
        readonly property bool modified: builtin && JSON.stringify(spec) !== JSON.stringify(baseline)

        function clone(o) { return JSON.parse(JSON.stringify(o)); }

        // ── loading / saving ─────────────────────────────────────
        function load(id) {
            const s = Theme.specOf(id, true) || Theme.specOf(Theme.validId(id), true);
            if (!s) return;
            Theme.clearDraft();
            themeId = s.id;
            spec = clone(s);
            saved = JSON.stringify(spec);
            undoStack = [];
            redoStack = [];
            openColor = "";
            scope = "";
        }
        function save() {
            if (builtin && !modified) Theme.removeTheme(themeId);   // identical to the built-in: no copy
            else Theme.saveTheme(clone(spec));
            saved = JSON.stringify(spec);
            Theme.clearDraft();
            app.flash("saved " + (spec.label || themeId));
        }
        function discard() {
            spec = JSON.parse(saved);
            Theme.clearDraft();
            openColor = "";
        }
        // a new theme, saved straight away so every widget can wear it
        function create(from, label) {
            const base = from ? clone(Theme.specOf(from, true) || {}) : { style: {}, colors: {} };
            const s = Object.assign(base, {
                id: Theme.freeId(label),
                label: label,
                cat: "mine",
                blurb: from ? "after " + Theme.labelOf(from) : "a new look"
            });
            if (!from) s.glyph = "\u{F03D8}";
            Theme.saveTheme(s);
            load(s.id);
            app.flash("made " + label);
        }
        function remove() {
            if (builtin) {                                       // a modified built-in: back to stock
                Theme.removeTheme(themeId);
                load(themeId);
                app.flash("reset " + Theme.labelOf(themeId) + " to the built-in");
                return;
            }
            const gone = themeId, st = Theme.clone(Theme.state);
            if (st.shared === gone) st.shared = Theme.fallbackId;
            for (const w in st.widgets) if (st.widgets[w] === gone) delete st.widgets[w];
            Theme.commit(st);
            Theme.removeTheme(gone);
            load(Theme.state.shared);
            app.flash("deleted " + gone);
        }

        // ── edits (every edit makes a new spec: bindings follow) ─
        function edit(fn, key) {
            const before = JSON.stringify(spec);
            const s = clone(spec);
            fn(s);
            tidy(s);
            if (JSON.stringify(s) === before) return;
            const now = Date.now();
            if (!(key && key === lastKey && now - lastTime < 900)) {   // a drag is one undo step
                undoStack = undoStack.concat([before]).slice(-200);
                redoStack = [];
            }
            lastKey = key || "";
            lastTime = now;
            spec = s;
        }
        function undo() {
            if (!undoStack.length) return;
            redoStack = redoStack.concat([JSON.stringify(spec)]);
            spec = JSON.parse(undoStack[undoStack.length - 1]);
            undoStack = undoStack.slice(0, -1);
            lastKey = "";
        }
        function redo() {
            if (!redoStack.length) return;
            undoStack = undoStack.concat([JSON.stringify(spec)]);
            spec = JSON.parse(redoStack[redoStack.length - 1]);
            redoStack = redoStack.slice(0, -1);
            lastKey = "";
        }
        // where an edit lands: the theme itself, or this widget's overrides
        function target(s, section) {
            if (scope === "") return (s[section] = s[section] || {});
            s.widgets = s.widgets || {};
            const w = (s.widgets[scope] = s.widgets[scope] || {});
            return (w[section] = w[section] || {});
        }
        function tidy(s) {
            if (!s.widgets) return;
            for (const w in s.widgets) {
                const o = s.widgets[w];
                for (const k of ["style", "colors"]) if (o[k] && !Object.keys(o[k]).length) delete o[k];
                if (!Object.keys(o).length) delete s.widgets[w];
            }
            if (!Object.keys(s.widgets).length) delete s.widgets;
        }
        function overridesIn(w) {
            const o = spec.widgets && spec.widgets[w];
            return o ? Object.keys(o.style || {}).length + Object.keys(o.colors || {}).length : 0;
        }
        function clearScope() { edit(s => { if (s.widgets) delete s.widgets[scope]; }); }

        // ── identity (the whole theme only) ──────────────────────
        function setMeta(k, v) { edit(s => { if (v === "" || v === undefined) delete s[k]; else s[k] = v; }, "meta." + k); }

        // ── style ────────────────────────────────────────────────
        readonly property var view: {
            const r = Theme.resolve(spec || {}, scope);
            return { pal: WalColors.data, r: r, env: { colors: r.colors, memo: {}, busy: {} }, tok: {} };
        }
        function style(k) { return view.r.style[k]; }
        function styleOverridden(k) {
            if (scope !== "") return !!(spec.widgets && spec.widgets[scope] && spec.widgets[scope].style && k in spec.widgets[scope].style);
            if (!baseline) return false;
            const a = Object.assign({}, Theme.styleDefaults, baseline.style || {});
            return JSON.stringify(view.r.style[k]) !== JSON.stringify(a[k]);
        }
        function setStyle(k, v) { edit(s => { target(s, "style")[k] = v; }, "style." + k); }
        function clearStyle(k) {
            edit(s => {
                if (scope !== "") { if (s.widgets && s.widgets[scope] && s.widgets[scope].style) delete s.widgets[scope].style[k]; return; }
                s.style = s.style || {};
                if (baseline && baseline.style && k in baseline.style) s.style[k] = clone(baseline.style[k]);
                else delete s.style[k];
            });
        }

        // ── colours ──────────────────────────────────────────────
        readonly property var colorNames: Object.keys(view.r.colors)
        function colorRaw(n) { return view.r.colors[n]; }
        function colorValue(n) { const v = view; return n in v.r.colors ? Theme.namedColor(n, v.env) : "transparent"; }
        function refValue(ref) { return Theme.evalColor(ref, view.env); }
        function colorOverridden(n) {
            if (scope !== "") return !!(spec.widgets && spec.widgets[scope] && spec.widgets[scope].colors && n in spec.widgets[scope].colors);
            if (!baseline) return false;
            const a = Object.assign({}, Theme.colorDefaults, baseline.colors || {});
            return JSON.stringify(view.r.colors[n]) !== JSON.stringify(a[n]);
        }
        // a recipe with no steps is stored as its plain source ("@aqua", "color5" …)
        function compact(r) {
            if (r && typeof r === "object" && Object.keys(r).length === 1 && "from" in r) return r.from;
            return r;
        }
        function setColor(n, r) { edit(s => { target(s, "colors")[n] = compact(r); }, "color." + n); }
        function clearColor(n) {
            edit(s => {
                if (scope !== "") { if (s.widgets && s.widgets[scope] && s.widgets[scope].colors) delete s.widgets[scope].colors[n]; return; }
                s.colors = s.colors || {};
                if (baseline && baseline.colors && n in baseline.colors) s.colors[n] = clone(baseline.colors[n]);
                else delete s.colors[n];
            });
        }
        function removeColor(n) {
            if (openColor === n) openColor = "";
            edit(s => {
                if (s.colors) delete s.colors[n];
                if (s.widgets) for (const w in s.widgets) if (s.widgets[w].colors) delete s.widgets[w].colors[n];
            });
        }
        function addColor(n, from) {
            n = String(n).trim().replace(/[^A-Za-z0-9_]/g, "");
            if (n === "" || n in view.r.colors) return;
            edit(s => { (s.colors = s.colors || {})[n] = from || "@accent"; });
            openColor = n;
        }
        function refLabel(ref) {
            ref = String(ref);
            return ref.charAt(0) === "@" ? ref.slice(1) : ref;
        }
        function describe(x) {
            if (x === undefined || x === null) return "\u{2014}";
            if (typeof x !== "object") return refLabel(x);
            const p = [refLabel(x.from === undefined ? "bg" : x.from)];
            if (x.lean) p.push("lean " + Math.round(x.lean[0] * 360) + "\u{00B0}");
            if (x.vivid) p.push("vivid");
            if (x.tone) p.push("tone");
            if (x.lighter) p.push("lighter " + x.lighter);
            if (x.darker) p.push("darker " + x.darker);
            if (x.mix) for (const m of x.mix) p.push("+ " + refLabel(m[0]) + " " + Math.round(m[1] * 100) + "%");
            if (x.alpha !== undefined && x.alpha !== null) p.push("\u{03B1} " + Math.round(x.alpha * 100) + "%");
            return p.join("  \u{00B7}  ");
        }

        // ── tokens for the previews (cached per spec revision) ───
        function tokensFor(w) {
            const v = view;
            const key = spec.widgets && spec.widgets[w] ? w : "";
            if (!v.tok[key]) v.tok[key] = Theme.compile(spec, key);
            return v.tok[key];
        }
        readonly property var tokens: tokensFor(scope !== "" ? scope : app.previewKey)
        readonly property var rawTokens: {
            const s = clone(spec);
            s.style = Object.assign({}, s.style || {}, { contrast: "off" });
            const v = view;                         // follow the palette too
            return Theme.compile(s, scope !== "" ? scope : app.previewKey);
        }

        // unsaved edits, worn live by the real widgets
        onSpecChanged: draftTimer.restart()
        onLiveChanged: draftTimer.restart()
    }
    Timer {
        id: draftTimer
        interval: 180
        onTriggered: {
            if (ed.live && ed.dirty && ed.themeId !== "") Theme.setDraft(ed.themeId, ed.spec);
            else Theme.clearDraft();
        }
    }

    // ══ studio state ═══════════════════════════════════════════════
    readonly property var editor: ed                // for children whose own `ed` property shadows the id
    property string preview: "all"                  // all · launcher · waybar · notifications · wallpicker · todo · controlcenter
    readonly property string previewKey: preview === "all" ? "launcher" : preview
    property string backdrop: "wallpaper"
    property bool motion: true
    property string query: ""
    property string message: ""
    property var thumbs: []
    property var pending: null                      // what to do once unsaved changes are settled
    property bool confirmDelete: false

    function flash(m) { message = m; flashTimer.restart(); }
    Timer { id: flashTimer; interval: 2600; onTriggered: app.message = "" }

    // switch theme / quit, asking first when there are unsaved changes
    function guard(action) {
        if (ed.dirty) pending = action;
        else action();
    }
    function settle(how) {                          // "save" · "discard" · "cancel"
        const a = pending;
        pending = null;
        if (how === "cancel" || !a) return;
        if (how === "save") ed.save(); else ed.discard();
        a();
    }
    function select(id) { guard(() => ed.load(id)); }

    // share a theme: export copies its json to the clipboard; import reads
    // one (or a whole theme file) from the clipboard and saves it as yours
    function exportTheme() {
        Quickshell.execDetached(["wl-copy", JSON.stringify(ed.spec, null, 2)]);
        flash("copied " + (ed.spec.label || ed.themeId) + " to the clipboard");
    }
    function importText(text) {
        let list = [];
        try { list = Theme.parseSet(text.trim().charAt(0) === "{" && !/"themes"\s*:/.test(text) ? "[" + text + "]" : text); }
        catch (e) { flash("the clipboard holds no theme"); return; }
        if (!list.length) { flash("the clipboard holds no theme"); return; }
        let first = "";
        for (const s of list) {
            const copy = JSON.parse(JSON.stringify(s));
            if (Theme.isBuiltin(copy.id) || Theme.userMap[copy.id]) {
                copy.id = Theme.freeId(copy.id);
                copy.label = (copy.label || copy.id) + " (imported)";
            }
            Theme.saveTheme(copy);
            if (!first) first = copy.id;
        }
        ed.load(first);
        flash("imported " + list.length + (list.length === 1 ? " theme" : " themes"));
    }
    Process {
        id: pasteProc
        command: ["wl-paste", "--no-newline"]
        stdout: StdioCollector { onStreamFinished: app.importText(text) }
    }
    function quit() { guard(() => { Theme.clearDraft(); Qt.quit(); }); }

    readonly property var previews: [
        { key: "all",           label: "desktop",       glyph: "\u{F0379}" },
        { key: "launcher",      label: "launcher",      glyph: "\u{F003B}" },
        { key: "waybar",        label: "waybar",        glyph: "\u{F1513}" },
        { key: "notifications", label: "notifications", glyph: "\u{F009A}" },
        { key: "wallpicker",    label: "wallpapers",    glyph: "\u{F0E09}" },
        { key: "todo",          label: "todo",          glyph: "\u{F0132}" },
        { key: "controlcenter", label: "control",       glyph: "\u{F062E}" },
        { key: "screenshot",    label: "screenshots",   glyph: "\u{F0100}" }
    ]

    // the theme's look options (Surface.qml, ThemedPanel.qml, Emblem.qml)
    readonly property var surfaces: ["flat", "gloss", "block", "gradient", "soft", "ricepill", "lens", "classic", "wii", "nixie", "xmb", "p5", "chrome"]
    readonly property var effects: ["none", "bubbles", "grid", "scanlines", "blobs", "banner", "petals", "aurora", "titlebar", "sweep", "eco", "wii", "divergence", "wave", "xbox", "dmg", "p5"]
    readonly property var emblems: ["glow", "orb", "prompt", "sun", "soft", "lens", "classic", "plain", "wii", "nixie", "luna", "p5"]
    readonly property var flags: [
        { k: "sheen",      l: "sheen",          n: "light across the top" },
        { k: "streak",     l: "streak",         n: "a diagonal glint" },
        { k: "swoosh",     l: "swoosh",         n: "aero's aurora swoosh" },
        { k: "hairline",   l: "hairline",       n: "neon top edge" },
        { k: "edge",       l: "lens edges",     n: "specular rims" },
        { k: "bevel",      l: "bevel",          n: "98-era 3d frames" },
        { k: "wellInset",  l: "inset wells",    n: "shadow inside lists" },
        { k: "fieldInset", l: "inset fields",   n: "recessed inputs" },
        { k: "raisedText", l: "raised text",    n: "embossed labels" },
        { k: "glow",       l: "glow",           n: "neon text halo" },
        { k: "halo",       l: "halo",           n: "accent halo" }
    ]
    readonly property var colorGroups: [
        { t: "accents", names: [
            { n: "accent",  l: "accent",         h: "selections, badges, highlights, the active tab" },
            { n: "accent2", l: "second accent",  h: "the other end of gradients and pills, secondary highlights" } ] },
        { t: "text", names: [
            { n: "text",    l: "text",           h: "body text (lifted or dimmed automatically until it reads)" },
            { n: "selText", l: "text on selection", h: "text drawn on a selected row or active tab" },
            { n: "match",   l: "search matches", h: "letters that match your search (optional)" } ] },
        { t: "glass", names: [
            { n: "panelTop",    l: "glass · top",    h: "the panel's gradient, top" },
            { n: "panelMid",    l: "glass · middle", h: "the panel's gradient, upper middle (text is judged on this)" },
            { n: "panelBottom", l: "glass · bottom", h: "the panel's gradient, bottom" },
            { n: "panelBorder", l: "glass · border", h: "the panel's outline" },
            { n: "rim",         l: "glass · inner rim", h: "a second line just inside the border" } ] },
        { t: "wells & fields", names: [
            { n: "well",        l: "well",           h: "recessed areas: result lists, stat boxes" },
            { n: "wellBorder",  l: "well · border",  h: "" },
            { n: "field",       l: "input field",    h: "search boxes and text inputs" },
            { n: "fieldBorder", l: "field · border", h: "" },
            { n: "fieldFocus",  l: "field · focus",  h: "the field's border while you type in it" } ] },
        { t: "status", names: [
            { n: "ok",   l: "ok",       h: "good news: battery charging, done (optional — default from the rice)" },
            { n: "warn", l: "warning",  h: "attention: idle mode, low-ish battery (optional)" },
            { n: "crit", l: "critical", h: "errors, deletion, power (optional)" } ] },
        { t: "bevel & title bar", names: [
            { n: "face",  l: "bevel face",   h: "classic: the button/window face" },
            { n: "light", l: "bevel light",  h: "classic: the lit edge" },
            { n: "shade", l: "bevel shadow", h: "classic: the shaded edge" },
            { n: "xp",    l: "title bar",    h: "luna: the xp title bar blue" } ] }
    ]
    readonly property var knownColors: {
        const out = [];
        for (const g of colorGroups) for (const x of g.names) out.push(x.n);
        return out;
    }

    Component.onCompleted: {
        Theme.widget = "studio";
        Theme.ignoreDraft = true;                   // the studio's own chrome never wears the draft
        const w = Quickshell.env("QS_STUDIO_WIDGET") || "";
        const id = Quickshell.env("QS_STUDIO_THEME") || Theme.effectiveFor(w || "launcher");
        ed.load(id);
        if (w !== "" && previews.some(p => p.key === w)) preview = w;
        thumbsProc.running = true;
    }
    Component.onDestruction: Theme.clearDraft()

    Process {                                       // a few real wallpapers for the picker preview
        id: thumbsProc
        command: ["sh", "-c", "ls -t \"$HOME\"/.cache/wallpicker/thumbs/*.jpg 2>/dev/null | head -6"]
        stdout: StdioCollector { onStreamFinished: app.thumbs = text.trim().split("\n").filter(x => x) }
    }

    IpcHandler {
        target: "studio"
        function ping(): string { return "ok"; }
        // open on a theme, previewing (and offering to edit for) a widget
        function open(theme: string, widget: string): void {
            if (theme !== "" && theme !== ed.themeId) app.select(theme);
            if (widget !== "" && app.previews.some(p => p.key === widget)) app.preview = widget;
        }
        function select(theme: string): void { app.select(theme); }
        function scope(widget: string): void { ed.scope = widget; }
        function preview(tab: string): void { app.preview = tab; }
        function scroll(y: int): void { insp.contentY = y; }      // test rigs: look further down
        function backdrop(b: string): void { app.backdrop = b; }
        function setStyle(key: string, json: string): void { ed.setStyle(key, JSON.parse(json)); }
        function setColor(name: string, json: string): void { ed.setColor(name, JSON.parse(json)); }
        function edit(name: string): void { ed.openColor = name; }
        function save(): void { ed.save(); }
        function discard(): void { ed.discard(); }
        function undo(): void { ed.undo(); }
        function create(label: string, from: string): void { ed.create(from, label); }
        function remove(): void { ed.remove(); }
        function exportTheme(): void { app.exportTheme(); }
        function importTheme(): void { pasteProc.running = true; }
        function importJson(text: string): void { app.importText(text); }     // test rigs: no clipboard
        function quit(): void { Theme.clearDraft(); Qt.quit(); }
        function state(): string {
            return JSON.stringify({ theme: ed.themeId, dirty: ed.dirty, scope: ed.scope, preview: app.preview,
                                    open: ed.openColor, undo: ed.undoStack.length, draft: Theme.draft ? Theme.draft.id : "" });
        }
    }

    // a row of options for one style key (surface, fx, emblem …)
    component OptionRow: ColumnLayout {
        id: opt
        property string key
        property string label
        property var options: []
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
            spacing: 6
            Mark { marked: ed.styleOverridden(opt.key); onCleared: ed.clearStyle(opt.key) }
            Text { text: opt.label; color: Theme.t.dim; font { family: Theme.t.font; pixelSize: 11 } }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: opt.options
                Btn {
                    required property string modelData
                    size: 24
                    label: modelData
                    on: ed.style(opt.key) === modelData
                    onClicked: ed.setStyle(opt.key, modelData)
                }
            }
        }
    }

    // ══ the window ════════════════════════════════════════════════
    FloatingWindow {
        id: win
        title: "theme studio"
        implicitWidth: 1520
        implicitHeight: 940
        minimumSize: Qt.size(1180, 760)
        color: "transparent"
        onClosed: { Theme.clearDraft(); Qt.quit(); }

        readonly property var th: Theme.t

        Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+S"; onActivated: ed.save() }
        Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+Z"; onActivated: ed.undo() }
        Shortcut { context: Qt.ApplicationShortcut; sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]; onActivated: ed.redo() }
        Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+D"; onActivated: ed.create(ed.themeId, Theme.labelOf(ed.themeId) + " copy") }
        Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+N"; onActivated: ed.create("", "my theme") }
        Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+L"; onActivated: ed.live = !ed.live }
        Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+Q"; onActivated: app.quit() }
        Shortcut {
            context: Qt.ApplicationShortcut
            sequence: "Escape"
            onActivated: {
                const f = chrome.Window.activeFocusItem;           // typing: esc just leaves the box
                if (f && f instanceof TextInput) { f.focus = false; return; }
                if (app.pending) app.settle("cancel");
                else if (ed.openColor !== "") ed.openColor = "";
                else app.quit();
            }
        }
        Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+1"; onActivated: app.preview = "all" }
        Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+2"; onActivated: app.preview = "launcher" }
        Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+3"; onActivated: app.preview = "waybar" }
        Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+4"; onActivated: app.preview = "notifications" }
        Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+5"; onActivated: app.preview = "wallpicker" }
        Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+6"; onActivated: app.preview = "todo" }
        Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+7"; onActivated: app.preview = "controlcenter" }
        Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+8"; onActivated: app.preview = "screenshot" }

        ThemedPanel {
            id: chrome
            anchors.fill: parent
            radius: 0
            animate: false
            title: "theme studio"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                anchors.topMargin: 14 + chrome.topInset
                spacing: 12

                // ── title bar ────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Emblem { glyph: "\u{F03D8}"; size: 40 }
                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: "theme studio"
                            color: win.th.text
                            font { family: win.th.font; pixelSize: 19; bold: true }
                        }
                        Text {
                            text: (ed.spec.label || ed.themeId) + "  \u{00B7}  "
                                  + (ed.builtin ? (ed.modified ? "built-in, changed" : "built-in") : "yours")
                                  + (ed.dirty ? "  \u{00B7}  unsaved" : "")
                            color: ed.dirty ? win.th.warnInk : win.th.dim
                            font { family: win.th.font; pixelSize: 12 }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        visible: app.message !== ""
                        text: app.message
                        color: win.th.okInk
                        font { family: win.th.font; pixelSize: 12 }
                    }
                    Btn { glyph: "\u{F054C}"; hint: "^Z"; enabled: ed.undoStack.length > 0; onClicked: ed.undo() }
                    Btn { glyph: "\u{F044E}"; hint: "^\u{21E7}Z"; enabled: ed.redoStack.length > 0; onClicked: ed.redo() }
                    Btn {
                        glyph: "\u{F0208}"
                        label: ed.live ? "live" : "here only"
                        hint: "^L"
                        on: ed.live
                        onClicked: ed.live = !ed.live
                    }
                    Btn { glyph: "\u{F099B}"; label: "discard"; enabled: ed.dirty; onClicked: ed.discard() }
                    Btn { glyph: "\u{F0193}"; label: "save"; hint: "^S"; primary: ed.dirty; enabled: ed.dirty; onClicked: ed.save() }
                    Btn { glyph: "\u{F0156}"; onClicked: app.quit() }
                }

                // ── unsaved-changes question ─────────────────────
                Item {
                    visible: app.pending !== null
                    Layout.fillWidth: true
                    implicitHeight: 40
                    Surface { anchors.fill: parent; tint: win.th.warn; strength: 0.5 }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 8
                        spacing: 10
                        Text {
                            Layout.fillWidth: true
                            text: "\u{F0026}  " + (ed.spec.label || ed.themeId) + " has unsaved changes"
                            color: win.th.text
                            font { family: win.th.glyphFont; pixelSize: 13 }
                        }
                        Btn { label: "save"; primary: true; onClicked: app.settle("save") }
                        Btn { label: "discard"; danger: true; onClicked: app.settle("discard") }
                        Btn { label: "cancel"; hint: "esc"; onClicked: app.settle("cancel") }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    // ══ the theme list ══════════════════════════
                    ColumnLayout {
                        Layout.preferredWidth: 250
                        Layout.minimumWidth: 250
                        Layout.maximumWidth: 250
                        Layout.fillHeight: true
                        spacing: 8

                        TextBox {
                            placeholder: "\u{F0349}  search themes"
                            onTextChanged: app.query = text
                        }
                        Well {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            ListView {
                                id: themeList
                                anchors.fill: parent
                                anchors.margins: 6
                                clip: true
                                spacing: 2
                                boundsBehavior: Flickable.StopAtBounds
                                // keep the theme being edited in view (new ones land at the end)
                                readonly property int selIndex: model.findIndex(x => x.id === ed.themeId)
                                onSelIndexChanged: if (selIndex >= 0) Qt.callLater(() => positionViewAtIndex(selIndex, ListView.Contain))
                                model: Theme.themes.filter(x => {
                                    const q = app.query.toLowerCase().trim();
                                    return q === "" || (x.label + " " + x.id + " " + x.cat + " " + x.blurb).toLowerCase().indexOf(q) >= 0;
                                })
                                delegate: Item {
                                    id: tRow
                                    required property var modelData
                                    readonly property bool sel: modelData.id === ed.themeId
                                    readonly property var wearers: Theme.widgets.filter(w => Theme.effectiveFor(w.key) === modelData.id)
                                    width: ListView.view.width
                                    height: 44
                                    Surface {
                                        anchors.fill: parent
                                        strength: tRow.sel ? 1 : (tHover.hovered ? 0.3 : 0)
                                        tick: true
                                    }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 8
                                        spacing: 9
                                        Text {
                                            text: tRow.modelData.glyph
                                            color: tRow.sel ? win.th.selText : win.th.ink
                                            font { family: win.th.glyphFont; pixelSize: 16 }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            Text {
                                                Layout.fillWidth: true
                                                text: tRow.modelData.label
                                                elide: Text.ElideRight
                                                color: tRow.sel ? win.th.selText : win.th.text
                                                font { family: win.th.font; pixelSize: 13; bold: tRow.sel }
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: (tRow.modelData.custom ? "yours" : tRow.modelData.modified ? "changed" : tRow.modelData.cat)
                                                      + (tRow.wearers.length ? "  \u{00B7}  worn by " + tRow.wearers.length : "")
                                                elide: Text.ElideRight
                                                color: tRow.sel ? win.th.selDim : win.th.faint
                                                font { family: win.th.font; pixelSize: 10 }
                                            }
                                        }
                                        Text {
                                            visible: tRow.modelData.custom || tRow.modelData.modified
                                            text: tRow.modelData.custom ? "\u{F03EB}" : "\u{F00E3}"
                                            color: tRow.sel ? win.th.selDim : win.th.faint
                                            font { family: win.th.glyphFont; pixelSize: 12 }
                                        }
                                    }
                                    HoverHandler { id: tHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: app.select(tRow.modelData.id) }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Btn { Layout.fillWidth: true; glyph: "\u{F0415}"; label: "new"; onClicked: app.guard(() => ed.create("", "my theme")) }
                            Btn { Layout.fillWidth: true; glyph: "\u{F018F}"; label: "copy"; onClicked: app.guard(() => ed.create(ed.themeId, Theme.labelOf(ed.themeId) + " copy")) }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Btn { Layout.fillWidth: true; glyph: "\u{F0207}"; label: "export"; onClicked: app.exportTheme() }
                            Btn { Layout.fillWidth: true; glyph: "\u{F02FA}"; label: "import"; onClicked: app.guard(() => pasteProc.running = true) }
                        }
                        Btn {
                            Layout.fillWidth: true
                            visible: !ed.builtin || Theme.isModified(ed.themeId)
                            glyph: ed.builtin ? "\u{F099B}" : "\u{F01B4}"
                            label: app.confirmDelete ? "click again to " + (ed.builtin ? "reset" : "delete")
                                                     : (ed.builtin ? "reset to built-in" : "delete theme")
                            danger: true
                            onClicked: {
                                if (!app.confirmDelete) { app.confirmDelete = true; confirmTimer.restart(); return; }
                                app.confirmDelete = false;
                                ed.remove();
                            }
                            Timer { id: confirmTimer; interval: 3000; onTriggered: app.confirmDelete = false }
                        }
                    }

                    // ══ the preview ═════════════════════════════
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 100
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Repeater {                        // which stand-in: label on the active one only
                                model: app.previews
                                Btn {
                                    required property var modelData
                                    size: 28
                                    glyph: modelData.glyph
                                    label: app.preview === modelData.key ? modelData.label : ""
                                    on: app.preview === modelData.key
                                    onClicked: app.preview = modelData.key
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Repeater {
                                model: [ { k: "wallpaper", g: "\u{F0E09}" }, { k: "dark", g: "\u{F0594}" }, { k: "light", g: "\u{F0599}" } ]
                                Btn {
                                    required property var modelData
                                    size: 28
                                    glyph: modelData.g
                                    on: app.backdrop === modelData.k
                                    onClicked: app.backdrop = modelData.k
                                }
                            }
                            Btn {
                                size: 28
                                glyph: app.motion ? "\u{F05D8}" : "\u{F1592}"
                                on: app.motion
                                onClicked: app.motion = !app.motion
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Stage {
                                id: stage
                                anchors.fill: parent
                                ed: app.editor
                                show: app.preview
                                backdrop: app.backdrop
                                animate: app.motion
                                thumbs: app.thumbs
                                stock: ed.themeId === "rice" && !ed.modified
                            }
                            Rectangle {                       // a frame around the stage
                                anchors.fill: parent
                                color: "transparent"
                                radius: 6
                                border.width: 1
                                border.color: Theme.alpha(win.th.text, 0.15)
                            }
                        }

                        // who wears this theme; click to put it on a widget
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: "wear on"
                                color: win.th.faint
                                font { family: win.th.font; pixelSize: 11 }
                            }
                            Repeater {
                                model: Theme.widgets
                                Btn {
                                    required property var modelData
                                    readonly property bool wears: Theme.effectiveFor(modelData.key) === ed.themeId
                                    size: 26
                                    glyph: modelData.glyph
                                    on: wears
                                    onClicked: Theme.pickFor(modelData.key, ed.themeId)
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                readonly property var wearers: Theme.widgets.filter(w => Theme.effectiveFor(w.key) === ed.themeId)
                                text: wearers.length ? "worn by " + wearers.map(w => w.label).join(" \u{00B7} ")
                                                     : "nobody wears it yet \u{2014} click a widget to put it on"
                                color: win.th.faint
                                font { family: win.th.font; pixelSize: 10 }
                            }
                        }
                    }

                    // ══ the inspector ═══════════════════════════
                    ColumnLayout {
                        Layout.preferredWidth: 440
                        Layout.minimumWidth: 440
                        Layout.maximumWidth: 440
                        Layout.fillHeight: true
                        spacing: 8

                        // editing for: the whole theme, or one widget
                        Flow {
                            Layout.fillWidth: true
                            spacing: 5
                            Btn {
                                size: 26
                                glyph: "\u{F0F59}"
                                label: "whole theme"
                                on: ed.scope === ""
                                onClicked: ed.scope = ""
                            }
                            Repeater {
                                model: Theme.widgets
                                Btn {
                                    required property var modelData
                                    readonly property int n: ed.overridesIn(modelData.key)
                                    size: 26
                                    glyph: modelData.glyph
                                    label: ed.scope === modelData.key ? modelData.label : (n ? String(n) : "")
                                    on: ed.scope === modelData.key
                                    onClicked: {
                                        ed.scope = modelData.key;
                                        if (app.previews.some(p => p.key === modelData.key)) app.preview = modelData.key;
                                    }
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: ed.scope === ""
                                ? "editing the theme for every widget \u{2014} pick a widget above to change it for that widget only"
                                : "editing for " + Theme.widgetLabel(ed.scope) + " only: changes here override the theme there ("
                                  + ed.overridesIn(ed.scope) + " so far). a dot marks an override \u{2014} click it to drop it."
                            color: ed.scope === "" ? win.th.faint : win.th.ink
                            font { family: win.th.font; pixelSize: 10 }
                        }

                        Well {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Flickable {
                                id: insp
                                anchors.fill: parent
                                anchors.margins: 10
                                clip: true
                                contentWidth: width
                                contentHeight: inspCol.implicitHeight
                                boundsBehavior: Flickable.StopAtBounds

                                ColumnLayout {
                                    id: inspCol
                                    width: insp.width - 6
                                    spacing: 10

                                    // ── readability ──────────────
                                    Section {
                                        title: "readability"
                                        glyph: "\u{F0301}"
                                        note: contrast.fails ? contrast.fails + " too faint" : "all readable"
                                        Contrast {
                                            id: contrast
                                            tok: ed.tokens
                                            raw: ed.rawTokens
                                        }
                                        Toggle {
                                            Layout.fillWidth: true
                                            label: "fix contrast automatically"
                                            note: "recommended"
                                            on: ed.style("contrast") !== "off"
                                            marked: ed.styleOverridden("contrast")
                                            onToggled: (v) => ed.setStyle("contrast", v ? "auto" : "off")
                                            onCleared: ed.clearStyle("contrast")
                                        }
                                    }

                                    // ── the theme ────────────────
                                    Section {
                                        title: "theme"
                                        glyph: "\u{F03EB}"
                                        visible: ed.scope === ""
                                        note: ed.themeId
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            TextBox {
                                                Layout.preferredWidth: 52
                                                Layout.fillWidth: false
                                                mono: true
                                                text: ed.spec.glyph || ""
                                                input.horizontalAlignment: TextInput.AlignHCenter
                                                onEdited: (t) => ed.setMeta("glyph", t.trim())
                                            }
                                            TextBox {
                                                text: ed.spec.label || ""
                                                placeholder: "name"
                                                onEdited: (t) => ed.setMeta("label", t.trim())
                                            }
                                        }
                                        TextBox {
                                            text: ed.spec.blurb || ""
                                            placeholder: "a few words about it"
                                            onEdited: (t) => ed.setMeta("blurb", t.trim())
                                        }
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 5
                                            Repeater {
                                                model: Theme.cats.filter(c => c.key !== "")
                                                Btn {
                                                    required property var modelData
                                                    size: 24
                                                    label: modelData.label
                                                    on: (ed.spec.cat || "mine") === modelData.key
                                                    onClicked: ed.setMeta("cat", modelData.key)
                                                }
                                            }
                                        }
                                        Flow {                         // glyphs to pick from
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Repeater {
                                                model: Theme.themes.map(x => x.glyph).concat(["\u{F03D8}", "\u{F0E09}", "\u{F0768}", "\u{F04CE}", "\u{F0266}", "\u{F00E3}", "\u{F05A9}", "\u{F0425}"])
                                                    .filter((g, i, a) => a.indexOf(g) === i)
                                                Item {
                                                    required property string modelData
                                                    width: 26
                                                    height: 26
                                                    Surface {
                                                        anchors.fill: parent
                                                        strength: ed.spec.glyph === parent.modelData ? 1 : (gHover.hovered ? 0.3 : 0)
                                                    }
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: parent.modelData
                                                        color: ed.spec.glyph === parent.modelData ? win.th.selText : win.th.dim
                                                        font { family: win.th.glyphFont; pixelSize: 14 }
                                                    }
                                                    HoverHandler { id: gHover; cursorShape: Qt.PointingHandCursor }
                                                    TapHandler { onTapped: ed.setMeta("glyph", parent.modelData) }
                                                }
                                            }
                                        }
                                        Toggle {
                                            Layout.fillWidth: true
                                            label: "dark theme"
                                            note: "off = a light theme"
                                            on: ed.style("dark") !== false
                                            marked: ed.styleOverridden("dark")
                                            onToggled: (v) => ed.setStyle("dark", v)
                                            onCleared: ed.clearStyle("dark")
                                        }
                                    }

                                    // ── surfaces ─────────────────
                                    Section {
                                        title: "surfaces"
                                        glyph: "\u{F0831}"
                                        note: "how things are drawn"
                                        OptionRow { key: "surface"; label: "selection style \u{2014} rows, tabs, buttons"; options: app.surfaces }
                                        OptionRow { key: "fx"; label: "background effect \u{2014} what lives in the glass"; options: app.effects }
                                        OptionRow {
                                            visible: ed.style("fx") === "titlebar"
                                            key: "titleStyle"
                                            label: "title bar"
                                            options: ["classic", "luna"]
                                        }
                                        OptionRow { key: "emblem"; label: "header badge"; options: app.emblems }
                                        Flow {                         // the badges, live
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Repeater {
                                                model: app.emblems
                                                Item {
                                                    required property string modelData
                                                    width: 34
                                                    height: 34
                                                    Emblem {
                                                        anchors.centerIn: parent
                                                        th: Object.assign({}, ed.tokens, { emblem: parent.modelData })
                                                        glyph: ed.spec.glyph || "\u{F03D8}"
                                                        size: 28
                                                    }
                                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                                    TapHandler { onTapped: ed.setStyle("emblem", parent.modelData) }
                                                }
                                            }
                                        }
                                    }

                                    // ── details ──────────────────
                                    Section {
                                        title: "details"
                                        glyph: "\u{F0768}"
                                        GridLayout {
                                            Layout.fillWidth: true
                                            columns: 2
                                            columnSpacing: 12
                                            rowSpacing: 2
                                            Repeater {
                                                model: app.flags
                                                Toggle {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    label: modelData.l
                                                    on: ed.style(modelData.k) === true
                                                    marked: ed.styleOverridden(modelData.k)
                                                    onToggled: (v) => ed.setStyle(modelData.k, v)
                                                    onCleared: ed.clearStyle(modelData.k)
                                                }
                                            }
                                        }
                                    }

                                    // ── shape ────────────────────
                                    Section {
                                        title: "shape"
                                        glyph: "\u{F0607}"
                                        ValueSlider {
                                            Layout.fillWidth: true
                                            label: "corner radius"
                                            value: ed.style("radius"); from: 0; to: 32; step: 1; decimals: 0
                                            marked: ed.styleOverridden("radius")
                                            onMoved: (v) => ed.setStyle("radius", v)
                                            onCleared: ed.clearStyle("radius")
                                        }
                                        ValueSlider {
                                            Layout.fillWidth: true
                                            label: "small radius"
                                            value: ed.style("radiusSm"); from: 0; to: 24; step: 1; decimals: 0
                                            marked: ed.styleOverridden("radiusSm")
                                            onMoved: (v) => ed.setStyle("radiusSm", v)
                                            onCleared: ed.clearStyle("radiusSm")
                                        }
                                        ValueSlider {
                                            Layout.fillWidth: true
                                            label: "shadow"
                                            value: ed.style("shadow"); from: 0; to: 1; step: 0.01
                                            marked: ed.styleOverridden("shadow")
                                            onMoved: (v) => ed.setStyle("shadow", v)
                                            onCleared: ed.clearStyle("shadow")
                                        }
                                        Toggle {
                                            Layout.fillWidth: true
                                            label: "pill-shaped tabs and fields"
                                            on: ed.style("pillFull") === true
                                            marked: ed.styleOverridden("pillFull")
                                            onToggled: (v) => ed.setStyle("pillFull", v)
                                            onCleared: ed.clearStyle("pillFull")
                                        }
                                    }

                                    // ── type ─────────────────────
                                    Section {
                                        title: "type"
                                        glyph: "\u{F06D6}"
                                        open: false
                                        readonly property var families: Qt.fontFamilies()
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6
                                            Mark { marked: ed.styleOverridden("font"); onCleared: ed.clearStyle("font") }
                                            Text { text: "font"; color: win.th.dim; Layout.preferredWidth: 70; font { family: win.th.font; pixelSize: 12 } }
                                            TextBox { text: ed.style("font") || ""; onEdited: (t) => ed.setStyle("font", t.trim()) }
                                        }
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            Repeater {
                                                model: ["Pixel Code", "JetBrainsMono Nerd Font", "CaskaydiaCove Nerd Font", "Iosevka", "Fira Code", "Hack", "Noto Sans", "Inter", "Monocraft", "Departure Mono"]
                                                       .filter(f => Qt.fontFamilies().indexOf(f) >= 0)
                                                Btn {
                                                    required property string modelData
                                                    size: 24
                                                    label: modelData
                                                    on: ed.style("font") === modelData
                                                    onClicked: ed.setStyle("font", modelData)
                                                }
                                            }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6
                                            Mark { marked: ed.styleOverridden("glyphFont"); onCleared: ed.clearStyle("glyphFont") }
                                            Text { text: "icons"; color: win.th.dim; Layout.preferredWidth: 70; font { family: win.th.font; pixelSize: 12 } }
                                            TextBox { text: ed.style("glyphFont") || ""; onEdited: (t) => ed.setStyle("glyphFont", t.trim()) }
                                        }
                                    }

                                    // ── colours ──────────────────
                                    Section {
                                        title: "colours"
                                        glyph: "\u{F0266}"
                                        note: "recipes over your walrs palette"
                                        Repeater {
                                            model: app.colorGroups
                                            ColumnLayout {
                                                id: grp
                                                required property var modelData
                                                readonly property var present: modelData.names.filter(x => ed.colorNames.indexOf(x.n) >= 0)
                                                readonly property var missing: modelData.names.filter(x => ed.colorNames.indexOf(x.n) < 0)
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text {
                                                    text: grp.modelData.t
                                                    color: win.th.faint
                                                    font { family: win.th.font; pixelSize: 10 }
                                                }
                                                Repeater {
                                                    model: grp.present
                                                    ColorRow {
                                                        required property var modelData
                                                        ed: app.editor
                                                        name: modelData.n
                                                        label: modelData.l
                                                        help: modelData.h
                                                    }
                                                }
                                                Flow {
                                                    visible: grp.missing.length > 0
                                                    Layout.fillWidth: true
                                                    spacing: 4
                                                    Repeater {
                                                        model: grp.missing
                                                        Btn {
                                                            required property var modelData
                                                            size: 22
                                                            glyph: "\u{F0415}"
                                                            label: modelData.l
                                                            onClicked: ed.addColor(modelData.n, modelData.n === "match" ? "@accent" : modelData.n)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        // helper colours: named steps other colours build on
                                        Text {
                                            text: "helpers \u{2014} named colours the others refer to as @name"
                                            color: win.th.faint
                                            font { family: win.th.font; pixelSize: 10 }
                                        }
                                        Repeater {
                                            model: ed.colorNames.filter(n => app.knownColors.indexOf(n) < 0)
                                            ColorRow {
                                                required property string modelData
                                                ed: app.editor
                                                name: modelData
                                                label: "@" + modelData
                                                removable: ed.scope === ""
                                            }
                                        }
                                        RowLayout {
                                            visible: ed.scope === ""
                                            Layout.fillWidth: true
                                            spacing: 6
                                            TextBox {
                                                id: helperName
                                                placeholder: "new helper name"
                                                onAccepted: (t) => { ed.addColor(t, "@accent"); helperName.text = ""; }
                                            }
                                            Btn {
                                                glyph: "\u{F0415}"
                                                label: "add"
                                                onClicked: { ed.addColor(helperName.text, "@accent"); helperName.text = ""; }
                                            }
                                        }
                                    }

                                    // ── per-widget overrides ─────
                                    Section {
                                        visible: ed.scope !== ""
                                        title: "overrides for " + Theme.widgetLabel(ed.scope)
                                        glyph: "\u{F0F59}"
                                        note: ed.overridesIn(ed.scope) + " set"
                                        Text {
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            text: JSON.stringify((ed.spec.widgets || {})[ed.scope] || {}, null, 1)
                                            color: win.th.dim
                                            font { family: win.th.font; pixelSize: 10 }
                                        }
                                        Btn {
                                            enabled: ed.overridesIn(ed.scope) > 0
                                            glyph: "\u{F01B4}"
                                            label: "drop every override for " + Theme.widgetLabel(ed.scope)
                                            danger: true
                                            onClicked: ed.clearScope()
                                        }
                                    }
                                    Item { implicitHeight: 20 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
