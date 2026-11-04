// ╔══════════════════════════════════════════════════════════════╗
// ║  wallpaper picker · themed overlay (quickshell)              ║
// ║  toggle: Super+Shift+W (hypr/scripts/qs-toggle.sh WallPicker)║
// ║                                                              ║
// ║  grid    type to search · ←→↑↓ move · chips: ★ recent folders║
// ║          ⏎ / click        crop view (frame it, then set)     ║
// ║          space            preview it on the desktop (esc     ║
// ║                           puts the old one back)             ║
// ║          ctrl+⏎ / middle  rice it as-is (walrs + wallpaper)  ║
// ║          ⇧⏎ / right click wallpaper only, palette untouched  ║
// ║          f ★ favourite · o show in files · ctrl+r surprise   ║
// ║          ctrl+s sort · ctrl+= / ctrl+- bigger / smaller      ║
// ║          ctrl+c copy its path · del del  move it to the trash║
// ║          home / end  first / last                            ║
// ║  colour  the dots filter by main colour (or type "blue",     ║
// ║          "dark", …) — read from the thumbnails, cached       ║
// ║  crop    drag / ←→↑↓ position · scroll / + - zoom · 0 reset  ║
// ║          fill or fit (blurred edges) · palette muted/vivid   ║
// ║          ⏎ set + rice · ⇧⏎ wallpaper only · esc back         ║
// ║  rotate  every 15/30/60 min through what's on screen (★,     ║
// ║          a folder, a search…) — keeps going after closing    ║
// ║  tabs    wallpapers · theme (ctrl+tab / alt+1,2)             ║
// ║                                                              ║
// ║  folders: folders.conf (or the 󰉋+ button) · thumbnails:      ║
// ║  thumbs.sh → ~/.cache/wallpicker/thumbs · favourites, recent ║
// ║  and view prefs: ~/.local/state/wallpicker/state.json        ║
// ╚══════════════════════════════════════════════════════════════╝
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "common"

PanelWindow {
    id: root

    readonly property var th: Theme.t
    readonly property int margin: 44
    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: Quickshell.shellDir           // thumbs.sh, rotate.sh live next to this file
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/wallpicker"
    property string tab: "walls"

    // sized to the panel, centred (see TodoWidget for why)
    implicitWidth: panel.width + margin * 2
    implicitHeight: panel.height + margin * 2
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-wallpicker"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: root.close()
    }

    // ── library ──────────────────────────────────────────────────
    property var all: []                 // { path, name, mtime, thumb, dims, group, ready, _n }
    property var byPath: ({})
    property var shown: []
    property string current: ""
    property string query: ""
    property string filter: ""           // "" all · "★" favourites · "recent" · folder name
    property string hue: ""              // "" any · a colour family (hues below) · "dark" · "light"
    property int thumbRev: 0             // bumps as thumbnails land
    property int making: 0
    property bool scanning: true
    property string toast: ""            // a line in the footer, for a moment
    property string hint: ""             // what a hovered colour dot means
    property string trashArmed: ""       // path waiting for a second del

    function say(msg) {
        root.toast = msg;
        toastTimer.restart();
    }
    Timer { id: toastTimer; interval: 3500; onTriggered: { root.toast = ""; root.trashArmed = ""; } }

    // ── colour families · from each thumbnail's six main colours ──
    // the swatch on a dot is a fixed sample of the family, not the theme
    readonly property var hues: [
        { key: "red",    swatch: "#e5484d", from: 345, to: 15 },
        { key: "orange", swatch: "#f76b15", from: 15,  to: 45 },
        { key: "yellow", swatch: "#ffc53d", from: 45,  to: 70 },
        { key: "green",  swatch: "#46a758", from: 70,  to: 160 },
        { key: "cyan",   swatch: "#12a594", from: 160, to: 200 },
        { key: "blue",   swatch: "#3e63dd", from: 200, to: 255 },
        { key: "purple", swatch: "#8e4ec6", from: 255, to: 290 },
        { key: "pink",   swatch: "#d6409f", from: 290, to: 345 },
        { key: "grey",   swatch: "#8b8d98" },
        { key: "dark",   swatch: "#16161a" },
        { key: "light",  swatch: "#f2f2f4" }
    ]
    property int colourRev: 0
    readonly property var hueCounts: {
        void root.colourRev;
        const n = {};
        for (const e of root.all) {
            if (e.hue) n[e.hue] = (n[e.hue] || 0) + 1;
            if (e.tone) n[e.tone] = (n[e.tone] || 0) + 1;
        }
        return n;
    }
    // "count#rrggbb,…" → e.hue (the most colourful family) and e.tone (dark / light / "")
    function classify(e) {
        e.hue = "";
        e.tone = "";
        if (!e.pal) return;
        let total = 0, lum = 0, best = null, bestScore = 0;
        for (const part of e.pal.split(",")) {
            const k = part.indexOf("#");
            const n = Number(part.slice(0, k)), c = Qt.color(part.slice(k));
            const hi = Math.max(c.r, c.g, c.b), lo = Math.min(c.r, c.g, c.b);
            total += n;
            lum += n * (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b);
            const score = n * Math.pow(hi - lo, 2);              // chroma, squared: colourful beats common
            if (hi - lo > 0.16 && score > bestScore) { bestScore = score; best = c; }
        }
        if (!total) return;
        lum /= total;
        e.tone = lum < 0.2 ? "dark" : lum > 0.62 ? "light" : "";
        if (!best) { e.hue = "grey"; return; }
        const h = best.hslHue * 360;
        const f = root.hues.find(x => x.from !== undefined && (x.from > x.to ? h >= x.from || h < x.to : h >= x.from && h < x.to));
        e.hue = f ? f.key : "grey";
    }
    function setHue(h) {
        root.hue = root.hue === h ? "" : h;
        search.forceActiveFocus();
    }

    // ── remembered between opens ─────────────────────────────────
    property var prefs: ({ favorites: [], recent: [], columns: 4, sort: "new", tone: "natural" })
    property int favRev: 0
    function isFav(p) { return root.favRev >= 0 && root.prefs.favorites.indexOf(p) >= 0; }
    function savePrefs() {
        Quickshell.execDetached(["mkdir", "-p", root.stateDir]);
        prefsFile.setText(JSON.stringify(root.prefs, null, 1));
    }
    FileView {
        id: prefsFile
        path: root.stateDir + "/state.json"
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            try {
                const p = JSON.parse(text());
                root.prefs = Object.assign({ favorites: [], recent: [], columns: 4, sort: "new", tone: "natural" }, p);
            } catch (e) {}
        }
    }
    function toggleFav(p) {
        if (!p) return;
        const f = root.prefs.favorites.filter(x => x !== p);
        if (f.length === root.prefs.favorites.length) f.unshift(p);
        root.prefs.favorites = f;
        root.favRev++;
        savePrefs();
        if (root.filter === "★") refilter();
    }
    function setColumns(n) {
        root.prefs.columns = Math.max(3, Math.min(6, n));
        root.prefs = Object.assign({}, root.prefs);
        savePrefs();
    }
    function setSort(s) {
        root.prefs.sort = s;
        root.prefs = Object.assign({}, root.prefs);
        savePrefs();
        refilter();
    }
    function setTone(t) {
        root.prefs.tone = t;
        root.prefs = Object.assign({}, root.prefs);
        savePrefs();
    }

    readonly property var groups: {
        const n = {};
        for (const e of root.all) if (e.group) n[e.group] = (n[e.group] || 0) + 1;
        return Object.keys(n).sort().map(k => ({ key: k, n: n[k] }));
    }
    readonly property var chips: {
        const out = [{ key: "", label: "all", glyph: "", n: root.all.length }];
        const favs = root.favRev >= 0 ? root.prefs.favorites.filter(p => root.byPath[p]).length : 0;
        out.push({ key: "★", label: "favourites", glyph: "󰓎", n: favs });
        const rec = root.prefs.recent.filter(p => root.byPath[p]).length;
        if (rec) out.push({ key: "recent", label: "recent", glyph: "󰋚", n: rec });
        for (const g of root.groups) out.push({ key: g.key, label: g.key.replace(/_/g, " "), glyph: "󰉋", n: g.n });
        return out;
    }

    // ── crop state ───────────────────────────────────────────────
    property string cropPath: ""         // "" = grid mode
    property var cropEntry: null
    property real cropScale: 1
    property real cropMin: 1
    property real cropOx: 0
    property real cropOy: 0
    property string fit: "fill"          // fill (crop) · fit (whole image, blurred edges)
    property var swatches: []

    readonly property int screenW: root.screen ? root.screen.width : 1920
    readonly property int screenH: root.screen ? root.screen.height : 1080

    // ── live preview ─────────────────────────────────────────────
    // grid peek: the image itself (awww centres and fills it).
    // crop peek: the frame you set up — rendered like the real thing,
    // and re-rendered as you drag, zoom or switch fill/fit.
    property string onDesktop: ""        // what awww showed when we opened
    property string previewing: ""       // the source image being peeked ("" = none)
    property bool peekFramed: false      // true while the peek follows the crop frame
    property int peekGen: 0              // alternating render targets
    property bool committed: false

    // ── rotation ─────────────────────────────────────────────────
    property string rotation: "off"      // "off" or "<min> <mode> <count>"
    readonly property int rotateMin: rotation === "off" ? 0 : Number(rotation.split(" ")[0])

    Component.onCompleted: Theme.widget = "wallpicker"

    function close() {
        // undo a peek: back to what was up when we opened — unless that was
        // itself a leftover peek render, then to the riced wallpaper
        const undo = root.previewing && !root.committed;
        Quickshell.execDetached(["sh", "-c",
            'if [ "$1" = 1 ]; then p="$2"; case "$p" in ""|*wallpicker-peek-*) p=$(cat "$HOME/.cache/wal/wal");; esac; ' +
            'awww img "$p" --transition-type fade --transition-duration 0.5; fi; ' +
            'rm -f "${XDG_RUNTIME_DIR:-/tmp}"/wallpicker-peek-*.png',
            "close", undo ? "1" : "0", root.onDesktop]);
        Qt.quit();
    }

    function setTab(t) {
        root.tab = t;
        if (t === "theme") picker.forceActiveFocus();
        else if (root.cropPath !== "") cropKeys.forceActiveFocus();
        else search.forceActiveFocus();
    }

    function refilter() {
        const words = root.query.toLowerCase().split(/\s+/).filter(w => w);
        let list;
        if (root.filter === "★") list = root.prefs.favorites.map(p => root.byPath[p]).filter(e => e);
        else if (root.filter === "recent") list = root.prefs.recent.map(p => root.byPath[p]).filter(e => e);
        else list = root.all.filter(e => !root.filter || e.group === root.filter);
        if (root.hue) list = list.filter(e => e.hue === root.hue || e.tone === root.hue);
        list = list.filter(e => words.every(w => e._n.indexOf(w) >= 0 || e.hue === w || e.tone === w));
        if (root.prefs.sort === "name" && root.filter !== "recent")
            list = list.slice().sort((a, b) => a.name.localeCompare(b.name));
        const keep = grid.currentIndex >= 0 && root.shown[grid.currentIndex] ? root.shown[grid.currentIndex].path : "";
        root.shown = list;
        const i = list.findIndex(e => e.path === (keep || root.current));
        grid.currentIndex = i >= 0 ? i : (list.length ? 0 : -1);
        if (grid.currentIndex >= 0)
            grid.positionViewAtIndex(grid.currentIndex, keep ? GridView.Contain : GridView.Center);
    }
    onQueryChanged: refilter()
    onFilterChanged: refilter()
    onHueChanged: refilter()

    // ── index + thumbnails (thumbs.sh) ───────────────────────────
    Process {
        id: scanProc
        running: true
        command: ["bash", root.dir + "/thumbs.sh", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [], map = {}, missing = [];
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f[0] === "CUR") root.current = (f[1] || "").trim();
                    else if (f[0] === "IMG" && f[2]) {
                        const e = {
                            path: f[2], mtime: Number(f[1]), thumb: f[3], dims: f[4] || "",
                            group: f[5] || "", name: f[2].split("/").pop(), ready: (f[4] || "") !== "",
                            pal: f[6] || ""
                        };
                        root.classify(e);
                        e._n = e.name.toLowerCase() + " " + e.group.toLowerCase();
                        list.push(e);
                        map[e.path] = e;
                        if (!e.ready) missing.push(e.path + "\t" + e.thumb);
                    }
                }
                root.all = list;
                root.byPath = map;
                root.scanning = false;
                root.colourRev++;
                root.refilter();
                if (missing.length) {
                    root.making = missing.length;
                    maker.pending = missing.join("\n") + "\n";
                    maker.running = true;
                } else {
                    root.readColours();
                }
            }
        }
    }

    Process {
        id: maker
        property string pending: ""
        command: ["bash", root.dir + "/thumbs.sh", "make"]
        stdinEnabled: true
        onStarted: { write(pending); stdinEnabled = false; }
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const f = line.split("\t");
                const e = root.byPath[f[1]];
                if (f[0] !== "DONE" || !e) return;
                e.ready = true;
                e.dims = f[2] || "";
                root.making = Math.max(0, root.making - 1);
                root.thumbRev++;
            }
        }
        onExited: { root.making = 0; root.readColours(); }
    }

    // colours for the thumbnails that don't have them yet (once each, cached)
    function readColours() {
        const todo = root.all.filter(e => e.ready && !e.pal).map(e => e.thumb);
        if (!todo.length || palProc.running) return;
        palProc.pending = todo.join("\n") + "\n";
        palProc.running = true;
    }
    Process {
        id: palProc
        property string pending: ""
        command: ["bash", root.dir + "/thumbs.sh", "pal"]
        stdinEnabled: true
        onStarted: { write(pending); stdinEnabled = false; }
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const f = line.split("\t");
                if (f[0] !== "PAL") return;
                const e = root.all.find(x => x.thumb === f[1]);
                if (!e) return;
                e.pal = f[2] || "";
                root.classify(e);
                colourBatch.restart();
            }
        }
    }
    Timer {                                     // results land in a burst: count once after it
        id: colourBatch
        interval: 250
        onTriggered: { root.colourRev++; if (root.hue) root.refilter(); }
    }

    Process {                                   // what's on the desktop right now
        running: true
        command: ["awww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/image:\s*(.+)\s*$/m);
                if (m) root.onDesktop = m[1].trim();
            }
        }
    }

    Process {
        id: rotStatus
        running: true
        command: ["bash", root.dir + "/rotate.sh", "status"]
        stdout: StdioCollector { onStreamFinished: root.rotation = text.trim() || "off" }
    }

    Process {                                   // a few colours from the image, for the crop view
        id: swatchProc
        stdout: StdioCollector {
            onStreamFinished: {
                const hex = (text.match(/#[0-9A-Fa-f]{6}/g) || []);
                const lum = h => { const c = Qt.color(h); return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b; };
                root.swatches = hex.sort((a, b) => lum(a) - lum(b)).slice(0, 8);
            }
        }
    }

    // ── actions ──────────────────────────────────────────────────
    // remember what we set: the "on screen" badge survives crops and
    // wallpaper-only sets (walrs only notes what it riced), and it
    // feeds the recent chip
    function note(path) {
        root.committed = true;
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$HOME/.cache/wallpicker" && printf "%s" "$1" > "$HOME/.cache/wallpicker/current"', "note", path]);
        root.prefs.recent = [path].concat(root.prefs.recent.filter(p => p !== path)).slice(0, 24);
        savePrefs();
    }

    function riceEnv() {
        return root.prefs.tone === "muted" ? ["RICE_SAT=-45"]
             : root.prefs.tone === "vivid" ? ["RICE_SAT=45"] : [];
    }

    // sh positional args keep odd filenames safe from quoting
    function wallOnly(path) {
        if (!path) return;
        note(path);
        Quickshell.execDetached(["sh", "-c",
            'exec awww img "$1" --transition-type grow --transition-duration 1.2', "awww", path]);
        Qt.quit();
    }

    function riceAsIs(path) {
        if (!path) return;
        note(path);
        Quickshell.execDetached(["env"].concat(riceEnv(), [root.home + "/.config/hypr/scripts/rice-apply.sh", path]));
        Qt.quit();
    }

    // peek (grid): put the image on the desktop now, the old one back on cancel
    function preview(path) {
        if (!path) return;
        root.previewing = path;
        root.peekFramed = false;
        Quickshell.execDetached(["awww", "img", path, "--transition-type", "fade", "--transition-duration", "0.35"]);
    }

    // ── rendering the frame ──────────────────────────────────────
    // fill: the framed region, scaled to the screen · fit: the whole
    // image over a blurred, darkened copy of itself. args: $1 source,
    // $2 crop geometry (real pixels), $3 screen size, $4 output
    readonly property bool cropReady: root.fit === "fit" || (cim.status === Image.Ready && cim.sourceSize.width > 0)

    function cropGeom() {
        const e = root.cropEntry;
        const real = e && e.dims ? e.dims.split("x").map(Number) : [cim.sourceSize.width, cim.sourceSize.height];
        const k = real[0] / cim.sourceSize.width;            // decoded → real pixels
        const s = root.cropScale;
        const x = Math.max(0, Math.round(-root.cropOx / s * k));
        const y = Math.max(0, Math.round(-root.cropOy / s * k));
        const w = Math.min(real[0] - x, Math.round(vp.width / s * k));
        const h = Math.min(real[1] - y, Math.round(vp.height / s * k));
        return w + "x" + h + "+" + x + "+" + y;
    }
    function renderScript() {
        return root.fit === "fit"
            ? 'magick "$1[0]" -auto-orient \\( +clone -resize "$3^" -gravity center -extent "$3" -blur 0x30 -modulate 75 \\) ' +
              '\\( -clone 0 -resize "$3" \\) -delete 0 -gravity center -composite "$4"'
            : 'magick "$1[0]" -auto-orient -crop "$2" +repage -resize "$3^" -gravity center -extent "$3" "$4"';
    }

    // peek (crop view): render the frame to a scratch file, show it
    function peekFrame() {
        if (!root.cropPath || !root.cropReady) return;
        root.previewing = root.cropPath;
        root.peekFramed = true;
        if (peekProc.running) { peekAgain.restart(); return; }      // one render at a time
        root.peekGen = (root.peekGen + 1) % 2;
        peekProc.command = ["sh", "-c",
            'set -e; ' + renderScript() + '; exec awww img "$4" --transition-type fade --transition-duration 0.3',
            "peek", root.cropPath, cropGeom(), root.screenW + "x" + root.screenH,
            (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/wallpicker-peek-" + root.peekGen + ".png"];
        peekProc.running = true;
    }
    Process { id: peekProc }
    Timer { id: peekAgain; interval: 450; onTriggered: root.peekFrame() }

    // a framed peek follows the frame: re-render once you stop adjusting
    function framingChanged() {
        if (root.peekFramed && root.previewing === root.cropPath && !dragArea.pressed) peekAgain.restart();
    }
    onCropOxChanged: framingChanged()
    onCropOyChanged: framingChanged()
    onCropScaleChanged: framingChanged()
    onFitChanged: framingChanged()

    // set it for real: render to a cache file (the original is
    // untouched), then rice it or just set it
    function confirmCrop(riceIt) {
        if (!root.cropReady) { confirmWhenReady.riceIt = riceIt; confirmWhenReady.armed = true; return; }
        const out = root.home + "/.cache/wallpicker/" + (root.fit === "fit" ? "fit-" : "crop-")
                  + root.cropPath.split("/").pop().replace(/\.[^.]*$/, "") + ".png";
        const tail = riceIt
            ? 'exec env ' + riceEnv().join(" ") + ' "$HOME/.config/hypr/scripts/rice-apply.sh" "$4"'
            : 'exec awww img "$4" --transition-type grow --transition-duration 1.2';

        note(root.cropPath);
        Quickshell.execDetached(["sh", "-c", 'set -e; mkdir -p "$HOME/.cache/wallpicker"; ' + renderScript() + '; ' + tail,
                                 "crop", root.cropPath, cropGeom(), root.screenW + "x" + root.screenH, out]);
        Qt.quit();
    }
    // ⏎ pressed before a big image finished decoding: finish the job then
    QtObject {
        id: confirmWhenReady
        property bool armed: false
        property bool riceIt: true
    }
    onCropReadyChanged: if (cropReady && confirmWhenReady.armed) {
        confirmWhenReady.armed = false;
        root.confirmCrop(confirmWhenReady.riceIt);
    }

    function openCrop(path) {
        if (!path) return;
        root.cropEntry = root.byPath[path] || null;
        root.cropPath = path;
        root.swatches = [];
        if (root.cropEntry && root.cropEntry.ready) {
            swatchProc.command = ["magick", root.cropEntry.thumb, "-resize", "64x64", "-colors", "8",
                                  "-unique-colors", "txt:-"];
            swatchProc.running = true;
        }
        cropKeys.forceActiveFocus();
    }
    function closeCrop() {
        root.peekFramed = false;
        root.cropPath = "";
        root.cropEntry = null;
        search.forceActiveFocus();
    }

    // del, then del again: into the desktop trash (gio), never deleted outright
    function trash(path) {
        if (!path) return;
        if (root.trashArmed !== path) {
            root.trashArmed = path;
            say("del again to move “" + path.split("/").pop() + "” to the trash");
            return;
        }
        root.trashArmed = "";
        Quickshell.execDetached(["gio", "trash", path]);
        const i = grid.currentIndex;
        root.all = root.all.filter(e => e.path !== path);
        const map = root.byPath;
        delete map[path];
        root.byPath = map;
        root.prefs.favorites = root.prefs.favorites.filter(p => p !== path);
        root.prefs.recent = root.prefs.recent.filter(p => p !== path);
        root.favRev++;
        savePrefs();
        root.refilter();
        grid.currentIndex = Math.min(i, root.shown.length - 1);
        root.colourRev++;
        say("moved to the trash  ·  restore it from your file manager's trash");
    }

    function copyPath(path) {
        if (!path) return;
        Quickshell.execDetached(["wl-copy", "--", path]);
        say("copied  " + path);
    }

    function surprise() {
        if (!root.shown.length) return;
        let i = Math.floor(Math.random() * root.shown.length);
        if (root.shown.length > 1 && root.shown[i].path === root.current) i = (i + 1) % root.shown.length;
        grid.currentIndex = i;
        openCrop(root.shown[i].path);
    }

    function showInFiles(path) {
        if (!path) return;
        Quickshell.execDetached(["dolphin", "--select", path]);
        root.close();
    }

    // rotation: off → 15 → 30 → 60 → off, through what's shown right now
    function cycleRotation() {
        const steps = [0, 15, 30, 60];
        const next = steps[(steps.indexOf(root.rotateMin) + 1) % steps.length];
        if (!next || !root.shown.length) {
            Quickshell.execDetached(["bash", root.dir + "/rotate.sh", "stop"]);
            root.rotation = "off";
            return;
        }
        const list = root.shown.map(e => e.path).join("\n") + "\n";
        Quickshell.execDetached(["sh", "-c",
            'f="${XDG_RUNTIME_DIR:-/tmp}/wallpicker-rotate.in"; printf "%s" "$1" > "$f"; exec bash "$2" start "$3" "$f" rice',
            "rot", list, root.dir + "/rotate.sh", String(next)]);
        root.rotation = next + " rice " + root.shown.length;
    }

    // add a folder through a picker dialog, then rescan
    Process {
        id: addFolder
        command: ["sh", "-c",
            'd=$(zenity --file-selection --directory --title="add a wallpaper folder") || exit 0;' +
            'grep -qxF "$d" "$1" 2>/dev/null || printf "%s\\n" "$d" >> "$1"', "add", root.dir + "/folders.conf"]
        onExited: { scanProc.running = true; }
    }

    function clampCrop() {
        root.cropOx = Math.min(0, Math.max(vp.width - cim.sourceSize.width * root.cropScale, root.cropOx));
        root.cropOy = Math.min(0, Math.max(vp.height - cim.sourceSize.height * root.cropScale, root.cropOy));
    }
    function zoomCrop(f) {
        const ns = Math.min(root.cropMin * 4, Math.max(root.cropMin, root.cropScale * f));
        const cx = vp.width / 2, cy = vp.height / 2;
        root.cropOx = cx - (cx - root.cropOx) * (ns / root.cropScale);
        root.cropOy = cy - (cy - root.cropOy) * (ns / root.cropScale);
        root.cropScale = ns;
        clampCrop();
    }
    function resetCrop() {
        const s0 = root.cropMin;
        root.cropScale = s0;
        root.cropOx = (vp.width - cim.sourceSize.width * s0) / 2;
        root.cropOy = (vp.height - cim.sourceSize.height * s0) / 2;
    }

    function gridKey(ev) {
        const cols = root.prefs.columns;
        const n = root.shown.length;
        const ctrl = ev.modifiers & Qt.ControlModifier, shift = ev.modifiers & Qt.ShiftModifier;
        const cur = root.shown[grid.currentIndex];
        let i = grid.currentIndex;
        switch (ev.key) {
        case Qt.Key_Left:  i -= 1; break;
        case Qt.Key_Right: i += 1; break;
        case Qt.Key_Up:    i -= cols; break;
        case Qt.Key_Down:  i += cols; break;
        case Qt.Key_PageUp:   i -= cols * 3; break;
        case Qt.Key_PageDown: i += cols * 3; break;
        case Qt.Key_Home:
            if (search.text !== "" && !ctrl) return false;
            i = 0;
            break;
        case Qt.Key_End:
            if (search.text !== "" && !ctrl) return false;
            i = n - 1;
            break;
        case Qt.Key_Delete:
            if (search.text !== "" && !shift) return false;
            if (cur) trash(cur.path);
            return true;
        case Qt.Key_C:
            if (!ctrl || search.selectedText !== "") return false;
            if (cur) copyPath(cur.path);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (cur) ctrl ? riceAsIs(cur.path) : shift ? wallOnly(cur.path) : openCrop(cur.path);
            return true;
        case Qt.Key_Space:
            if (search.text !== "" && !ctrl) return false;     // a space inside a search
            if (cur) preview(cur.path);
            return true;
        case Qt.Key_F:
            if (search.text !== "" && !ctrl) return false;
            if (cur) toggleFav(cur.path);
            return true;
        case Qt.Key_O:
            if (search.text !== "" && !ctrl) return false;
            if (cur) showInFiles(cur.path);
            return true;
        case Qt.Key_R:
            if (!ctrl) return false;
            surprise();
            return true;
        case Qt.Key_S:
            if (!ctrl) return false;
            setSort(root.prefs.sort === "new" ? "name" : "new");
            return true;
        case Qt.Key_Equal:
        case Qt.Key_Plus:
            if (!ctrl) return false;
            setColumns(root.prefs.columns - 1);              // fewer columns = bigger cards
            return true;
        case Qt.Key_Minus:
            if (!ctrl) return false;
            setColumns(root.prefs.columns + 1);
            return true;
        default:
            return false;
        }
        root.trashArmed = "";
        if (n) {
            grid.currentIndex = Math.max(0, Math.min(n - 1, i));
            grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
        }
        return true;
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (root.tab === "walls" && root.cropPath !== "") root.closeCrop();
            else if (root.tab === "walls" && search.text !== "") search.text = "";
            else root.close();
        }
    }
    Shortcut { sequence: "Ctrl+Tab"; context: Qt.ApplicationShortcut; onActivated: root.setTab(root.tab === "walls" ? "theme" : "walls") }
    Shortcut { sequence: "Alt+1"; context: Qt.ApplicationShortcut; onActivated: root.setTab("walls") }
    Shortcut { sequence: "Alt+2"; context: Qt.ApplicationShortcut; onActivated: root.setTab("theme") }

    // clicks in the transparent margin close it
    MouseArea { anchors.fill: parent; onClicked: root.close() }

    // ── a small label on a card ──────────────────────────────────
    component Badge: Item {
        id: bdg
        property string text
        property color fill
        property color ink
        implicitWidth: badgeText.implicitWidth + 12
        implicitHeight: 17
        Rectangle { anchors.fill: parent; radius: root.th.pillFull ? 8 : 3; color: bdg.fill }
        Text {
            id: badgeText
            anchors.centerIn: parent
            text: bdg.text
            color: bdg.ink
            font { family: root.th.font; pixelSize: 9; bold: true }
        }
    }

    // ── a pill button ────────────────────────────────────────────
    component Pill: Item {
        id: pill
        property string label
        property string glyph
        property bool accent: false
        property bool on: false
        signal tapped()
        implicitHeight: 32
        implicitWidth: pillRow.implicitWidth + 24
        Surface {
            anchors.fill: parent
            radius: root.th.pillFull ? height / 2 : root.th.radiusSm
            tint: pill.accent || pill.on ? root.th.accent : root.th.text
            strength: pill.accent || pill.on ? (pillHover.hovered ? 1 : 0.92) : (pillHover.hovered ? 0.45 : 0.22)
        }
        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 7
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: pill.glyph !== ""
                text: pill.glyph
                color: pill.accent || pill.on ? root.th.selText : root.th.dim
                font { family: root.th.glyphFont; pixelSize: 14 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: pill.label !== ""
                text: pill.label
                color: pill.accent || pill.on ? root.th.selText : root.th.text
                font { family: root.th.font; pixelSize: 12; bold: pill.accent }
            }
        }
        HoverHandler { id: pillHover }
        TapHandler { onTapped: pill.tapped() }
    }

    // ── the panel ────────────────────────────────────────────────
    ThemedPanel {
        id: panel
        title: "wallpapers"
        x: root.margin
        y: root.margin
        width: 980
        height: 700

        opacity: 0
        scale: 0.96
        Component.onCompleted: { opacity = 1; scale = 1; Qt.callLater(() => search.forceActiveFocus()); }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
        Behavior on scale   { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

        MouseArea { anchors.fill: parent }   // swallow clicks

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            anchors.topMargin: 18 + panel.topInset
            spacing: 12

            // ── header ───────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Emblem {
                    size: 38
                    glyph: root.tab === "theme" ? "󰏘" : root.cropPath !== "" ? "󰆞" : "󰸉"
                }
                Text {
                    Layout.fillWidth: true
                    text: root.tab === "theme" ? "theme"
                        : root.cropPath !== "" ? root.cropPath.split("/").pop() : "wallpapers"
                    elide: Text.ElideMiddle
                    color: root.th.text
                    font { family: root.th.font; pixelSize: 19; bold: true }
                }
                Item {
                    visible: root.tab === "walls"
                    implicitWidth: countText.implicitWidth + 18
                    implicitHeight: 24
                    Surface { anchors.fill: parent; radius: root.th.pillFull ? 12 : root.th.radiusSm; strength: 0.45 }
                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: root.cropPath !== ""
                            ? (root.cropEntry && root.cropEntry.dims ? root.cropEntry.dims.replace("x", "×")
                                                                     : cim.sourceSize.width + "×" + cim.sourceSize.height)
                            : root.scanning ? "…"
                            : root.shown.length === root.all.length ? root.all.length + " wallpapers"
                            : root.shown.length + " of " + root.all.length
                        color: root.th.text
                        font { family: root.th.font; pixelSize: 12 }
                    }
                }
                TabBar {
                    model: [
                        { key: "walls", label: "wallpapers", glyph: "󰋹" },
                        { key: "theme", label: "theme", glyph: "󰏘" }
                    ]
                    current: root.tab
                    onPicked: (key) => root.setTab(key)
                }
            }

            // ── toolbar ──────────────────────────────────────────
            RowLayout {
                visible: root.tab === "walls" && root.cropPath === ""
                Layout.fillWidth: true
                spacing: 8

                Field {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    focused: search.activeFocus
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 8
                        Text {
                            text: "󰍉"
                            color: root.th.faint
                            font { family: root.th.glyphFont; pixelSize: 14 }
                        }
                        TextInput {
                            id: search
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            color: root.th.text
                            selectionColor: Theme.alpha(root.th.accent, 0.45)
                            selectedTextColor: root.th.selText
                            font { family: root.th.font; pixelSize: 14 }
                            clip: true
                            onTextChanged: root.query = text
                            Keys.onPressed: (ev) => { ev.accepted = root.gridKey(ev); }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: search.text === ""
                                text: "search wallpapers…"
                                color: root.th.faint
                                font { family: root.th.font; pixelSize: 14; italic: true }
                            }
                        }
                    }
                }
                Pill {
                    glyph: root.prefs.sort === "new" ? "󱕋" : "󰖽"
                    label: root.prefs.sort === "new" ? "newest" : "a–z"
                    onTapped: { root.setSort(root.prefs.sort === "new" ? "name" : "new"); search.forceActiveFocus(); }
                }
                Pill {
                    glyph: "󰒟"
                    label: "surprise"
                    onTapped: root.surprise()
                }
                Pill {
                    glyph: "󰑓"
                    label: root.rotateMin ? "every " + root.rotateMin + "m" : "rotate"
                    on: root.rotateMin > 0
                    onTapped: { root.cycleRotation(); search.forceActiveFocus(); }
                }
                Pill {
                    glyph: "󰉋"
                    label: "+"
                    onTapped: addFolder.running = true
                }
            }

            // ── chips: all · favourites · recent · folders · colours ──
            RowLayout {
                visible: root.tab === "walls" && root.cropPath === ""
                Layout.fillWidth: true
                spacing: 12
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: root.chips
                    delegate: Item {
                        id: chip
                        required property var modelData
                        readonly property bool active: root.filter === modelData.key
                        implicitWidth: chipRow.implicitWidth + 20
                        implicitHeight: 26
                        Surface {
                            anchors.fill: parent
                            radius: root.th.pillFull ? height / 2 : root.th.radiusSm
                            tint: chip.active ? root.th.accent : root.th.text
                            strength: chip.active ? 1 : (chipHover.hovered ? 0.4 : 0.15)
                        }
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: chip.modelData.glyph !== ""
                                text: chip.modelData.glyph
                                color: chip.active ? root.th.selText : chip.modelData.key === "★" ? root.th.warn : root.th.dim
                                font { family: root.th.glyphFont; pixelSize: 12 }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.label + "  " + chip.modelData.n
                                color: chip.active ? root.th.selText : root.th.dim
                                font { family: root.th.font; pixelSize: 11 }
                            }
                        }
                        HoverHandler { id: chipHover }
                        TapHandler { onTapped: { root.filter = chip.modelData.key; search.forceActiveFocus(); } }
                    }
                }
            }
            Row {                                       // colour dots
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 4
                spacing: 4
                Repeater {
                    model: root.hues
                    delegate: Item {
                        id: dot
                        required property var modelData
                        readonly property int n: root.hueCounts[modelData.key] || 0
                        readonly property bool active: root.hue === modelData.key
                        visible: n > 0 || active
                        width: 18
                        height: 18
                        Rectangle {                     // ring when active
                            anchors.centerIn: parent
                            width: 18; height: 18; radius: 9
                            color: "transparent"
                            border.width: 2
                            border.color: root.th.accent
                            visible: dot.active
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: dotHover.hovered || dot.active ? 12 : 11
                            height: width
                            radius: width / 2
                            color: dot.modelData.swatch
                            border.width: 1
                            border.color: Theme.alpha(root.th.text, 0.35)
                            opacity: root.hue && !dot.active ? 0.45 : 1
                        }
                        HoverHandler {
                            id: dotHover
                            onHoveredChanged: root.hint = hovered ? dot.modelData.key + " · " + dot.n
                                                               : (root.hint.startsWith(dot.modelData.key + " ") ? "" : root.hint)
                        }
                        TapHandler { onTapped: root.setHue(dot.modelData.key) }
                    }
                }
            }
            }

            // ── theme tab ────────────────────────────────────────
            ThemePicker {
                id: picker
                visible: root.tab === "theme"
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // ── grid ─────────────────────────────────────────────
            GridView {
                id: grid
                visible: root.tab === "walls" && root.cropPath === ""
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.shown
                cellWidth: Math.floor(width / root.prefs.columns)
                cellHeight: Math.floor(cellWidth * 0.68)
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: cellHeight * 2
                currentIndex: -1
                highlightFollowsCurrentItem: false

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight

                    readonly property bool isCurrent: modelData.path === root.current
                    readonly property bool isPeek: modelData.path === root.previewing
                    readonly property bool sel: cell.GridView.isCurrentItem
                    readonly property bool fav: root.isFav(modelData.path)
                    readonly property bool ready: root.thumbRev >= 0 && modelData.ready
                    readonly property var wh: (root.thumbRev >= 0 && modelData.dims ? modelData.dims : "0x0").split("x").map(Number)
                    readonly property bool lowRes: wh[0] > 0 && (wh[0] < root.screenW || wh[1] < root.screenH)

                    Item {
                        id: card
                        anchors.fill: parent
                        anchors.margins: 5

                        Surface {
                            anchors.fill: parent
                            radius: root.th.radiusSm + 2
                            strength: cell.isCurrent || cardMouse.containsMouse || cell.sel ? 1 : 0.16
                            tint: cell.isCurrent ? root.th.accent : cell.sel || cardMouse.containsMouse ? root.th.accent2 : root.th.text
                        }

                        ClippingRectangle {
                            id: thumbBox
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: Math.max(0, root.th.radiusSm - 2)
                            color: Theme.alpha(root.th.text, 0.05)

                            Image {
                                id: img
                                anchors.fill: parent
                                source: cell.ready ? "file://" + cell.modelData.thumb : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: img.status !== Image.Ready
                                text: cell.ready ? "…" : "󰋩"
                                color: root.th.faint
                                font { family: root.th.glyphFont; pixelSize: 18 }
                            }

                            // name + size, on hover / when selected
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 24
                                visible: cardMouse.containsMouse || cell.sel
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0) }
                                    GradientStop { position: 0.4; color: Qt.rgba(0, 0, 0, 0.6) }
                                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 6
                                    Text {
                                        Layout.fillWidth: true
                                        text: cell.modelData.name
                                        elide: Text.ElideMiddle
                                        color: "white"
                                        font { family: root.th.font; pixelSize: 10 }
                                    }
                                    Text {
                                        visible: cell.wh[0] > 0
                                        text: cell.wh[0] + "×" + cell.wh[1]
                                        color: Qt.rgba(1, 1, 1, 0.7)
                                        font { family: root.th.font; pixelSize: 9 }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onClicked: (m) => {
                                grid.currentIndex = cell.index;
                                if (m.button === Qt.RightButton) root.wallOnly(cell.modelData.path);
                                else if (m.button === Qt.MiddleButton) root.riceAsIs(cell.modelData.path);
                                else root.openCrop(cell.modelData.path);
                            }
                        }

                        // badges: low-res · peeking · on screen
                        Row {
                            anchors.top: thumbBox.top
                            anchors.right: thumbBox.right
                            anchors.margins: 6
                            spacing: 4
                            Badge { visible: cell.lowRes; text: "low-res"; fill: Theme.alpha(root.th.warn, 0.9); ink: "#1a1206" }
                            Badge { visible: cell.isPeek; text: "previewing"; fill: Theme.alpha(root.th.accent2, 0.95); ink: "white" }
                            Badge { visible: cell.isCurrent; text: "on screen"; fill: root.th.accent; ink: root.th.dark ? "white" : "#ffffff" }
                        }

                        // favourite star (top-left): always when ★, else on hover
                        Item {
                            anchors.top: thumbBox.top
                            anchors.left: thumbBox.left
                            anchors.margins: 5
                            width: 24
                            height: 24
                            visible: cell.fav || cardMouse.containsMouse || starMouse.containsMouse
                            Rectangle { anchors.fill: parent; radius: 12; color: Qt.rgba(0, 0, 0, 0.55) }
                            Text {
                                anchors.centerIn: parent
                                text: cell.fav ? "󰓎" : "󰓒"
                                color: cell.fav ? root.th.warn : "white"
                                font { family: root.th.glyphFont; pixelSize: 14 }
                            }
                            MouseArea {
                                id: starMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.toggleFav(cell.modelData.path)
                            }
                        }
                    }
                }

                // empty states
                Column {
                    anchors.centerIn: parent
                    visible: root.shown.length === 0 && !root.scanning
                    spacing: 12
                    Emblem {
                        anchors.horizontalCenter: parent.horizontalCenter
                        glyph: root.filter === "★" ? "󰓒" : root.all.length ? "󰍉" : "󰸉"
                        opacity: 0.75
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.filter === "★" && !root.query ? "no favourites yet · hover a wallpaper and tap its star (or press f)"
                            : root.all.length ? "nothing matches “" + root.query + "”"
                            : "nothing found · add a folder with 󰉋+"
                        color: root.th.faint
                        font { family: root.th.font; pixelSize: 13; italic: true }
                    }
                }
            }

            // ── crop view ────────────────────────────────────────
            RowLayout {
                visible: root.tab === "walls" && root.cropPath !== ""
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    Item {
                        id: stage
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        readonly property real ratio: root.screenW / root.screenH

                    Rectangle {
                        id: vpFrame
                        // screen-shaped viewport, as big as fits: what you frame is what you get
                        width: Math.floor(Math.min(stage.width, stage.height * stage.ratio))
                        height: Math.floor(width / stage.ratio)
                        anchors.centerIn: parent
                        color: "#000000"
                        border.width: 1
                        border.color: Theme.alpha(root.th.accent, 0.6)

                        Item {
                            id: vp
                            anchors.fill: parent
                            anchors.margins: 1
                            clip: true

                            // fit mode: the whole image over a blurred, darkened copy
                            Image {
                                anchors.fill: parent
                                visible: root.fit === "fit"
                                source: root.cropEntry && root.cropEntry.ready ? "file://" + root.cropEntry.thumb : ""
                                fillMode: Image.PreserveAspectCrop
                                opacity: 0.45
                                smooth: true
                                sourceSize.width: 48                    // tiny on purpose: upscaled = blurred
                            }
                            Image {
                                anchors.fill: parent
                                visible: root.fit === "fit"
                                source: root.fit === "fit" && root.cropPath !== "" ? "file://" + root.cropPath : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                autoTransform: true
                                sourceSize.width: 1920
                            }

                            Image {
                                id: cim
                                visible: root.fit === "fill"
                                // big originals decode at ≤ 3840 px; the crop maps back to real pixels
                                readonly property var real: root.cropEntry && root.cropEntry.dims
                                    ? root.cropEntry.dims.split("x").map(Number) : [0, 0]
                                readonly property real cap: real[0] > 0 ? Math.min(1, 3840 / Math.max(real[0], real[1])) : 1
                                source: root.cropPath !== "" ? "file://" + root.cropPath : ""
                                autoTransform: true
                                sourceSize: real[0] > 0 ? Qt.size(Math.round(real[0] * cap), Math.round(real[1] * cap)) : undefined
                                asynchronous: true
                                x: root.cropOx
                                y: root.cropOy
                                width: sourceSize.width * root.cropScale
                                height: sourceSize.height * root.cropScale
                                onStatusChanged: if (status === Image.Ready) {
                                    const s0 = Math.max(vp.width / sourceSize.width,
                                                        vp.height / sourceSize.height);
                                    root.cropMin = s0;
                                    root.cropScale = s0;
                                    root.cropOx = (vp.width - sourceSize.width * s0) / 2;
                                    root.cropOy = (vp.height - sourceSize.height * s0) / 2;
                                }
                            }

                            // while the big image decodes: its thumbnail
                            Image {
                                anchors.fill: parent
                                visible: cim.status !== Image.Ready && root.cropEntry && root.cropEntry.ready
                                source: root.cropEntry && root.cropEntry.ready ? "file://" + root.cropEntry.thumb : ""
                                fillMode: Image.PreserveAspectCrop
                                opacity: 0.6
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: cim.status !== Image.Ready
                                text: "decoding…"
                                color: "white"
                                font { family: root.th.font; pixelSize: 14; italic: true }
                            }

                            // rule of thirds — firm while you drag
                            Item {
                                anchors.fill: parent
                                visible: root.fit === "fill"
                                opacity: dragArea.pressed ? 0.55 : 0.14
                                Behavior on opacity { NumberAnimation { duration: 160 } }
                                Repeater {
                                    model: 2
                                    Rectangle {
                                        required property int index
                                        x: vp.width * (index + 1) / 3; width: 1; height: vp.height
                                        color: "white"
                                    }
                                }
                                Repeater {
                                    model: 2
                                    Rectangle {
                                        required property int index
                                        y: vp.height * (index + 1) / 3; height: 1; width: vp.width
                                        color: "white"
                                    }
                                }
                            }

                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                enabled: root.fit === "fill"
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                property real px: 0
                                property real py: 0
                                onPressed: (m) => { px = m.x; py = m.y; cropKeys.forceActiveFocus(); }
                                onReleased: root.framingChanged()
                                onPositionChanged: (m) => {
                                    if (!pressed) return;
                                    root.cropOx += m.x - px;
                                    root.cropOy += m.y - py;
                                    px = m.x; py = m.y;
                                    root.clampCrop();
                                }
                                onWheel: (w) => root.zoomCrop(w.angleDelta.y > 0 ? 1.08 : 1 / 1.08)
                            }
                        }

                        // keyboard: ←→↑↓ pan (⇧ faster) · + - zoom · 0 reset · ⏎ set
                        Item {
                            id: cropKeys
                            focus: root.cropPath !== ""
                            Keys.onPressed: (ev) => {
                                const step = ev.modifiers & Qt.ShiftModifier ? 80 : 20;
                                let done = true;
                                switch (ev.key) {
                                case Qt.Key_Left:  root.cropOx += step; root.clampCrop(); break;
                                case Qt.Key_Right: root.cropOx -= step; root.clampCrop(); break;
                                case Qt.Key_Up:    root.cropOy += step; root.clampCrop(); break;
                                case Qt.Key_Down:  root.cropOy -= step; root.clampCrop(); break;
                                case Qt.Key_Plus:
                                case Qt.Key_Equal: root.zoomCrop(1.1); break;
                                case Qt.Key_Minus: root.zoomCrop(1 / 1.1); break;
                                case Qt.Key_0:     root.resetCrop(); break;
                                case Qt.Key_Tab:   root.fit = root.fit === "fill" ? "fit" : "fill"; break;
                                case Qt.Key_Space: root.peekFrame(); break;
                                case Qt.Key_Return:
                                case Qt.Key_Enter: root.confirmCrop(!(ev.modifiers & Qt.ShiftModifier)); break;
                                default: done = false;
                                }
                                ev.accepted = done;
                            }
                        }
                    }

                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Pill { glyph: "󰁍"; label: "back"; onTapped: root.closeCrop() }
                        Pill { visible: root.fit === "fill"; label: "reset"; onTapped: root.resetCrop() }
                        Text {
                            visible: root.fit === "fill"
                            text: Math.round(root.cropScale / root.cropMin * 100) + "%"
                            color: root.th.faint
                            font { family: root.th.font; pixelSize: 12 }
                        }
                        Item { Layout.fillWidth: true }
                        Pill {
                            glyph: "󰛐"
                            label: peekProc.running ? "rendering…" : root.peekFramed && root.previewing === root.cropPath ? "peeking · live" : "peek"
                            on: root.peekFramed && root.previewing === root.cropPath
                            onTapped: root.peekFrame()
                        }
                        Pill { label: "wallpaper only"; onTapped: root.confirmCrop(false) }
                        Pill { glyph: "󰸉"; label: "set · rice"; accent: true; onTapped: root.confirmCrop(true) }
                    }
                }

                // ── side: framing · palette · info ───────────────
                ColumnLayout {
                    Layout.preferredWidth: 190
                    Layout.fillHeight: true
                    spacing: 10

                    component Section: Text {
                        color: root.th.faint
                        font { family: root.th.font; pixelSize: 11 }
                    }
                    component Choice: Item {
                        id: ch
                        property string label
                        property string glyph
                        property bool on
                        signal tapped()
                        Layout.fillWidth: true
                        implicitHeight: 30
                        Surface {
                            anchors.fill: parent
                            radius: root.th.pillFull ? height / 2 : root.th.radiusSm
                            tint: ch.on ? root.th.accent : root.th.text
                            strength: ch.on ? 1 : (chHover.hovered ? 0.4 : 0.15)
                        }
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Text {
                                text: ch.glyph
                                color: ch.on ? root.th.selText : root.th.dim
                                font { family: root.th.glyphFont; pixelSize: 13 }
                            }
                            Text {
                                text: ch.label
                                color: ch.on ? root.th.selText : root.th.text
                                font { family: root.th.font; pixelSize: 12 }
                            }
                        }
                        HoverHandler { id: chHover }
                        TapHandler { onTapped: ch.tapped() }
                    }

                    Section { text: "framing  ·  tab" }
                    Choice { glyph: "󰆞"; label: "fill · crop to screen"; on: root.fit === "fill"; onTapped: root.fit = "fill" }
                    Choice { glyph: "󰹑"; label: "fit · blurred edges"; on: root.fit === "fit"; onTapped: root.fit = "fit" }

                    Section { text: "palette when riced"; Layout.topMargin: 6 }
                    Choice { glyph: "󰃞"; label: "muted"; on: root.prefs.tone === "muted"; onTapped: root.setTone("muted") }
                    Choice { glyph: "󰃟"; label: "natural"; on: root.prefs.tone === "natural"; onTapped: root.setTone("natural") }
                    Choice { glyph: "󰃠"; label: "vivid"; on: root.prefs.tone === "vivid"; onTapped: root.setTone("vivid") }

                    Section { text: "colours in it"; Layout.topMargin: 6 }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 5
                        Repeater {
                            model: root.swatches
                            Rectangle {
                                required property string modelData
                                width: 20
                                height: 20
                                radius: root.th.bevel ? 0 : 6
                                color: modelData
                                border.width: 1
                                border.color: Theme.alpha(root.th.text, 0.2)
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Choice {
                        glyph: root.cropEntry && root.isFav(root.cropEntry.path) ? "󰓎" : "󰓒"
                        label: root.cropEntry && root.isFav(root.cropEntry.path) ? "favourite" : "add to favourites"
                        on: root.cropEntry !== null && root.isFav(root.cropEntry.path)
                        onTapped: if (root.cropEntry) root.toggleFav(root.cropEntry.path)
                    }
                    Choice { glyph: "󰝰"; label: "show in files"; on: false; onTapped: root.showInFiles(root.cropPath) }
                }
            }

            // ── footer ───────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Keycap { visible: root.tab === "walls" && root.cropPath === "" && root.toast === "" && root.hint === ""; keys: "⏎"; label: "crop" }
                Keycap { visible: root.tab === "walls" && root.cropPath === "" && root.toast === "" && root.hint === ""; keys: "space"; label: "peek" }
                Keycap { visible: root.tab === "walls" && root.cropPath === "" && root.toast === "" && root.hint === ""; keys: "^⏎"; label: "rice as-is" }
                Keycap { visible: root.tab === "walls" && root.cropPath === "" && root.toast === "" && root.hint === ""; keys: "⇧⏎"; label: "wall only" }
                Keycap { visible: root.tab === "walls" && root.cropPath === "" && root.toast === "" && root.hint === ""; keys: "f"; label: "★" }
                Keycap { visible: root.tab === "walls" && root.cropPath === "" && root.toast === "" && root.hint === ""; keys: "^± "; label: "size" }
                Keycap { visible: root.tab === "walls" && root.cropPath !== ""; keys: "←→↑↓"; label: "move" }
                Keycap { visible: root.tab === "walls" && root.cropPath !== ""; keys: "+ −"; label: "zoom" }
                Keycap { visible: root.tab === "walls" && root.cropPath !== ""; keys: "tab"; label: "fill/fit" }
                Keycap { visible: root.tab === "walls" && root.cropPath !== ""; keys: "space"; label: "peek" }
                Keycap { visible: root.tab === "walls" && root.cropPath !== ""; keys: "⏎"; label: "set · rice" }
                Keycap { visible: root.tab === "theme"; keys: "⏎"; label: "apply" }
                Keycap { visible: root.tab === "theme"; keys: "L"; label: "link" }
                Keycap { visible: root.tab === "theme"; keys: "E"; label: "studio" }
                Keycap { visible: root.tab === "theme"; keys: "T"; label: "target" }
                Text {
                    visible: root.making > 0 && root.toast === ""
                    text: "making thumbnails · " + root.making + " to go"
                    color: root.th.faint
                    font { family: root.th.font; pixelSize: 11; italic: true }
                }
                Text {
                    visible: root.making === 0 && palProc.running && root.toast === ""
                    text: "reading colours…"
                    color: root.th.faint
                    font { family: root.th.font; pixelSize: 11; italic: true }
                }
                Text {
                    visible: root.toast !== "" || root.hint !== ""
                    Layout.fillWidth: true
                    text: root.toast || root.hint
                    elide: Text.ElideMiddle
                    color: root.trashArmed ? root.th.critInk : root.th.dim
                    font { family: root.th.font; pixelSize: 12; bold: root.trashArmed !== ""; italic: root.toast !== "" && !root.trashArmed }
                }
                Item { Layout.fillWidth: true }
                Keycap { keys: "^tab"; label: "tabs" }
                Keycap { keys: "esc"; label: root.tab === "walls" && root.cropPath !== "" ? "back" : root.previewing ? "close · undo peek" : "close" }
            }
        }
    }
}
