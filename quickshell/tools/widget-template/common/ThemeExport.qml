// ╔══════════════════════════════════════════════════════════════╗
// ║  ThemeExport · dresses waybar from the shared theme          ║
// ║  waybar is gtk, not qml — so the always-running launcher     ║
// ║  daemon renders waybar's effective theme to css and reloads  ║
// ║  the bar whenever the theme state or the palette changes.    ║
// ║                                                              ║
// ║    ~/.cache/quickshell-theme/waybar.css                      ║
// ║      "rice": just imports waybar/base.css (the bar as riced) ║
// ║      others: a full stylesheet from the theme's tokens       ║
// ║    ~/.cache/quickshell-theme/waybar.sh                       ║
// ║      shell vars for waybar's rofi power menu                 ║
// ║    ~/.cache/quickshell-theme/dunst.conf                      ║
// ║      dunst drop-in (dunstrc.d/50-theme.conf links here) for  ║
// ║      the "notifications" theme; "rice" leaves pywal's look   ║
// ║    ~/.cache/quickshell-theme/hyprquickframe.toml             ║
// ║      the screenshot tool (HyprQuickFrame, Alt+S) reads it    ║
// ║      via ~/.config/hyprquickframe/theme.toml (a link here)   ║
// ╚══════════════════════════════════════════════════════════════╝
import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: ex
    // QS_EXPORT_DIR / QS_EXPORT_WIDGET let a test rig render elsewhere, from another widget's theme
    property string widget: Quickshell.env("QS_EXPORT_WIDGET") || "waybar"
    readonly property string notifWidget: Quickshell.env("QS_EXPORT_WIDGET") || "notifications"
    readonly property string dir: Quickshell.env("QS_EXPORT_DIR") || (Quickshell.env("HOME") + "/.cache/quickshell-theme")
    readonly property var th: Theme.tokens(Theme.effectiveFor(widget), widget)
    readonly property string css: build(th)
    readonly property string vars: shellVars(th)
    readonly property var nth: Theme.tokens(Theme.effectiveFor(notifWidget), notifWidget)
    // "rice" as shipped leaves waybar and dunst exactly as you riced them;
    // once you change it in the theme studio it's generated like the rest
    function stock(t) { return t.id === "rice" && Theme.isStock("rice"); }
    readonly property string dunst: dunstConf(nth)
    readonly property string shotWidget: Quickshell.env("QS_EXPORT_WIDGET") || "screenshot"
    readonly property var sth: Theme.tokens(Theme.effectiveFor(shotWidget), shotWidget)
    readonly property string shot: shotToml(sth)
    property bool ready: false

    onCssChanged: if (ready) debounce.restart()
    onDunstChanged: if (ready) debounce.restart()
    // the power menu's colours: with "rice" the css and dunst text never
    // change, so without this they went stale after every re-rice
    onVarsChanged: if (ready) debounce.restart()
    onShotChanged: if (ready) debounce.restart()
    // long enough to land after the full reload walrs' rice hook sends
    Timer { id: debounce; interval: 900; onTriggered: ex.flush() }

    Process {
        id: mkdir
        running: true
        command: ["mkdir", "-p", ex.dir]
        onExited: { ex.ready = true; debounce.restart(); }
    }

    // waybar crashes if SIGUSR2 reloads arrive back to back, so a theme
    // change never signals it: rewriting its one-line loader (style.css,
    // same bytes) trips reload_style_on_change — a css-only reload
    FileView {
        id: cssFile
        path: ex.dir + "/waybar.css"
        blockLoading: true
        printErrors: false
        // same bytes, rewritten in place (FileView would skip an identical
        // write); no loader to poke → fall back to a reload signal
        onSaved: Quickshell.execDetached(["sh", "-c",
            'f="$1"; if [ -f "$f" ]; then c=$(cat "$f"); printf "%s\\n" "$c" > "$f"; else pkill -SIGUSR2 -x waybar; fi',
            "poke", Quickshell.env("QS_EXPORT_POKE") || (Quickshell.env("HOME") + "/.config/waybar/style.css")])
    }
    FileView {
        id: dunstFile
        path: ex.dir + "/dunst.conf"
        blockLoading: true
        printErrors: false
        onSaved: Quickshell.execDetached(["dunstctl", "reload"])
    }
    FileView {
        id: varsFile
        path: ex.dir + "/waybar.sh"
        blockLoading: true
        printErrors: false
    }
    FileView {                         // read fresh at every screenshot: nothing to reload
        id: shotFile
        path: ex.dir + "/hyprquickframe.toml"
        blockLoading: true
        printErrors: false
    }

    function flush() {
        if (varsFile.text() !== vars) varsFile.setText(vars);
        if (cssFile.text() !== css) cssFile.setText(css);   // saved → waybar reloads
        if (dunstFile.text() !== dunst) dunstFile.setText(dunst);   // saved → dunst reloads
        if (shotFile.text() !== shot) shotFile.setText(shot);
    }

    // ── helpers ──────────────────────────────────────────────────
    function rgba(c, a) {
        const q = Qt.color(String(c));
        const al = a === undefined ? q.a : a;
        return "rgba(" + Math.round(q.r * 255) + ", " + Math.round(q.g * 255) + ", "
             + Math.round(q.b * 255) + ", " + (Math.round(al * 1000) / 1000) + ")";
    }
    function hex(c) {
        const q = Qt.color(String(c));
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return "#" + h(q.r) + h(q.g) + h(q.b);
    }
    function lighter(c, f) { return Qt.lighter(String(c), f); }
    function darker(c, f) { return Qt.darker(String(c), f); }

    // a selected/active surface as gtk css (borders as inset shadows so
    // hover never changes a module's size)
    function surface(t, tint, s) {
        switch (t.surface) {
        case "gloss":
            return "background-image: linear-gradient(to bottom, rgba(255,255,255," + (0.38 * s) + ") 0%, rgba(255,255,255," + (0.10 * s) + ") 48%, rgba(255,255,255,0) 50%), "
                 + "linear-gradient(to bottom, " + rgba(lighter(tint, 1.25), (t.dark ? 0.80 : 0.95) * s) + ", " + rgba(tint, (t.dark ? 0.62 : 0.90) * s) + " 50%, " + rgba(darker(tint, 1.25), (t.dark ? 0.74 : 0.93) * s) + ");\n"
                 + "    box-shadow: inset 0 0 0 1px " + rgba(lighter(tint, 1.15), 0.95 * s) + ", inset 0 0 0 2px rgba(255,255,255," + (0.22 * s) + ");";
        case "block":
            return "background-image: none; background-color: " + rgba(tint, (s >= 0.99 ? 0.92 : 0.22) * s) + ";\n"
                 + "    box-shadow: " + (s >= 0.99 ? "none" : "inset 0 0 0 1px " + rgba(tint, 0.5 * s)) + ";";
        case "gradient":
            return "background-image: linear-gradient(to right, " + rgba(tint, 0.70 * s) + ", " + rgba(t.accent2, 0.55 * s) + ");\n"
                 + "    box-shadow: inset 0 1px rgba(255,255,255," + (0.45 * s) + "), inset 0 0 0 1px " + rgba(lighter(tint, 1.3), 0.7 * s) + ";";
        case "soft":
            return "background-image: none; background-color: " + rgba(tint, 0.17 * s) + ";\n"
                 + "    box-shadow: inset 0 0 0 1px " + rgba(tint, 0.42 * s) + ", inset 0 1px rgba(255,255,255," + (0.7 * s) + ");";
        case "ricepill":
            return "background-image: linear-gradient(to right, " + rgba(tint, 0.30 * s) + ", " + rgba(t.accent2, 0.10 * s) + ");\n"
                 + "    box-shadow: inset 0 0 0 1px " + rgba(tint, 0.20 * s) + ";";
        case "lens":
            return "background-image: linear-gradient(to bottom, rgba(255,255,255," + (0.16 * s) + "), " + rgba(tint, 0.34 * s) + " 35%, " + rgba(tint, 0.46 * s) + ");\n"
                 + "    box-shadow: inset 0 1px rgba(255,255,255," + (0.85 * s) + "), inset 0 0 0 1px rgba(255,255,255," + (0.5 * s) + ");";
        case "classic":
            return s >= 0.99
                ? "background-image: none; background-color: " + rgba(tint, 1) + "; box-shadow: none;"
                : "background-image: none; background-color: " + rgba(t.face, 1) + ";\n"
                  + "    box-shadow: inset 1px 1px " + rgba(t.light, 1) + ", inset -1px -1px " + rgba(t.shade, 1) + ";";
        case "wii":
            return "background-image: none; background-color: rgba(255,255,255," + (0.96 * Math.min(1, s * 1.6)) + ");\n"
                 + "    box-shadow: " + (s >= 0.99 ? "inset 0 0 0 2px " + rgba(tint) + ", 0 0 6px " + rgba(tint, 0.45)
                                                   : "inset 0 0 0 1px rgba(154,154,154," + Math.min(1, s * 1.6) + ")") + ";";
        case "nixie":
            return "background-image: linear-gradient(to bottom, " + rgba(tint, 0.06 * s) + ", " + rgba(tint, 0.18 * s) + ");\n"
                 + "    box-shadow: inset 0 0 0 1px " + rgba(tint, 0.7 * s) + ", inset 0 -2px " + rgba(lighter(tint, 1.3), 0.5 * s) + ";";
        case "xmb":
            return "background-image: linear-gradient(to right, rgba(255,255,255," + (0.10 * s) + "), rgba(255,255,255," + (0.32 * s) + ") 25%, rgba(255,255,255," + (0.20 * s) + ") 80%, rgba(255,255,255," + (0.08 * s) + "));\n"
                 + "    box-shadow: inset 0 1px rgba(255,255,255," + (0.55 * s) + "), inset 0 -1px rgba(255,255,255," + (0.30 * s) + "), 0 0 8px rgba(255,255,255," + (0.25 * s) + ");";
        case "p5":
            return s >= 0.99
                ? "background-image: none; background-color: " + rgba(tint) + "; box-shadow: inset 0 0 0 2px #ffffff, 3px 3px 0 #000000;"
                : "background-image: none; background-color: rgba(255,255,255," + (0.14 * s) + "); box-shadow: inset 0 0 0 1px " + rgba(tint, 0.6 * s) + ";";
        case "chrome":
            return "background-image: "
                 + (s >= 0.99 ? "linear-gradient(to right, " + rgba(tint, 0.35) + ", " + rgba(t.accent2, 0.35) + "), " : "")
                 + "linear-gradient(to bottom, rgba(255,255,255," + (0.95 * s) + "), " + rgba("#c9cfd8", 0.95 * s) + " 46%, "
                 + rgba("#98a1ae", 0.95 * s) + " 50%, " + rgba("#e8ecf1", 0.95 * s) + ");\n"
                 + "    box-shadow: inset 0 0 0 1px " + rgba("#5b6370", 0.9 * s) + ";";
        default:                                            // flat
            return "background-image: none; background-color: " + rgba(tint, 0.15 * s) + ";\n"
                 + "    box-shadow: inset 0 0 0 1px " + rgba(tint, 0.38 * s) + ";";
        }
    }

    function halo(t, c) {
        if (t.glow)
            return "0 0 1px " + rgba(t.text, 0.9) + ", 0 0 6px " + rgba(c, 0.55) + ", 0 0 12px " + rgba(c, 0.28);
        if (t.raisedText) return "0 1px 1px rgba(0, 0, 0, 0.45)";
        return "none";
    }

    function shellVars(t) {
        return "# generated by quickshell common/ThemeExport.qml — waybar wears: " + t.id + "\n"
             + "qt_theme='" + t.id + "'\n"
             + "qt_bg='" + hex(t.dark ? t.panelMid : t.panelTop) + "'\n"
             + "qt_fg='" + hex(t.text) + "'\n"
             + "qt_accent='" + hex(t.accent) + "'\n"
             + "qt_alt='" + hex(t.accent2) + "'\n"
             + "qt_sel_fg='" + hex(t.selText) + "'\n"
             + "qt_radius=" + Math.min(16, t.radius) + "\n"
             + "qt_font='" + t.font + "'\n";
    }

    // ── HyprQuickFrame · the screenshot overlay ──────────────────
    // its own theme.toml format: [bar] background → barBackground …
    function shotToml(t) {
        const bg = t.dark ? t.panelMid : t.panelTop;
        // its lit segment is a SOLID accent: label it black or white, whichever reads
        const onFill = Theme.contrast("#ffffff", t.fill) >= Theme.contrast("#111318", t.fill) ? "#ffffff" : "#111318";
        return "# generated by quickshell common/ThemeExport.qml — screenshots wear: " + t.id + "\n"
             + "# HyprQuickFrame reads it through ~/.config/hyprquickframe/theme.toml (a link here).\n"
             + "# pick a look in any widget's theme tab (for: screenshots); this file is rewritten.\n"
             + `accent = "${hex(t.fill)}"
accentText = "${onFill}"
dimOpacity = ${t.dark ? 0.6 : 0.45}
borderRadius = ${t.bevel ? 0 : Math.min(14, t.radiusSm)}
outlineThickness = 2
bottomMargin = 60
animations = ${Theme.motion}
annotationTool = "satty"

[bar]
background = "${rgba(bg, Math.max(0.55, Qt.color(String(bg)).a))}"
border = "${rgba(t.panelBorder)}"
text = "${rgba(t.text, 0.8)}"
shadow = "#80000000"

[toggle]
shadow = "#80000000"
edit = "${hex(t.okInk)}"
temp = "${hex(t.ink)}"

[share]
connected = "${hex(t.ink)}"
pending = "${rgba(t.faint)}"
errorIcon = "white"
errorBackground = "${hex(t.crit)}"

[hooks]
postSaveHook = ""
`;
    }

    // ── dunst · a drop-in over dunstrc + 00-pywal.conf ───────────
    function dunstHex(c, a) {
        const q = Qt.color(String(c));
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return "#" + h(q.r) + h(q.g) + h(q.b) + h(a === undefined ? q.a : a);
    }
    function dunstConf(t) {
        const head = "# generated by quickshell common/ThemeExport.qml — notifications wear: " + t.id + "\n"
                   + "# pick another in any widget's theme tab (for: notifications)\n";
        if (stock(t))
            return head + "# rice: dunstrc + 00-pywal.conf stand as riced\n";
        const bg = t.dark ? t.panelMid : t.panelTop;
        const glassA = Math.max(0.86, Qt.color(String(bg)).a);       // dunst draws no blur of its own
        const R = t.bevel ? 0 : Math.min(18, t.radius);
        const frame = t.bevel ? t.shade : t.panelBorder;
        return head + `
[global]
    corner_radius = ${R}
    frame_width = ${t.bevel || t.edge ? 2 : 1}
    icon_corner_radius = ${t.bevel ? 0 : Math.min(10, t.radiusSm)}
    progress_bar_corner_radius = ${t.bevel ? 0 : 4}
    font = ${t.font} 11
    separator_color = frame
    highlight = "${dunstHex(t.accent, 1)}, ${dunstHex(t.accent2, 1)}"

[urgency_low]
    background = "${dunstHex(bg, glassA)}"
    foreground = "${dunstHex(t.text, 0.7)}"
    frame_color = "${dunstHex(frame, 0.5)}"

[urgency_normal]
    background = "${dunstHex(bg, glassA)}"
    foreground = "${dunstHex(t.text, 1)}"
    frame_color = "${dunstHex(frame, t.bevel ? 1 : 0.9)}"

[urgency_critical]
    background = "${dunstHex(bg, Math.min(1, glassA + 0.06))}"
    foreground = "${dunstHex(t.text, 1)}"
    frame_color = "${dunstHex(t.crit, 1)}"
    highlight = "${dunstHex(t.crit, 1)}"
`;
    }

    // ── the stylesheet ───────────────────────────────────────────
    function build(t) {
        if (stock(t))
            return "/* generated by quickshell common/ThemeExport.qml — waybar wears: rice */\n"
                 + "/* the bar exactly as riced: ~/.config/waybar/base.css */\n"
                 + "@import url(\"file://" + Quickshell.env("HOME") + "/.config/waybar/base.css\");\n";

        const R = Math.min(18, t.radius), r = t.bevel ? 0 : Math.min(13, t.radiusSm + 3), p = t.bevel ? 0 : Math.min(11, t.radiusSm);
        const text = t.text, accent = t.accent, faint = t.faint;
        const darkTip = !t.dark;                           // calendar spans are palette-light: keep tooltips dark
        const tipBg = darkTip ? Theme.alpha(WalColors.background, 0.95) : Theme.alpha(t.panelMid, 0.96);
        const tipFg = darkTip ? WalColors.foreground : text;
        const well = String(t.well) === "#00000000" || t.well === "transparent"
            ? Theme.alpha(text, 0.06) : t.well;
        const sheen = t.sheen ? "linear-gradient(to bottom, rgba(255,255,255," + (t.dark ? 0.16 : 0.42) + ") 0%, rgba(255,255,255,0.03) 55%, rgba(255,255,255,0) 100%), " : "";
        const barShadow = t.bevel
            ? "inset 1px 1px " + rgba(t.light) + ", inset -1px -1px #000000, inset 2px 2px " + rgba(lighter(t.face, 1.1)) + ", inset -2px -2px " + rgba(t.shade)
            : t.edge ? "inset 0 1px rgba(255,255,255,0.85), inset 0 -1px rgba(255,255,255,0.25)" : "none";
        const H = (c) => halo(t, c);

        return `/* generated by quickshell common/ThemeExport.qml — waybar wears: ${t.id}
   pick another in any widget's theme tab (or waybar's 󰏘 button);
   change the theme itself in the theme studio (Super+Shift+P).
   don't edit this file: it is rewritten on every theme change. */

* {
    font-family: "${t.font}", "CaskaydiaCove Nerd Font", "JetBrainsMono Nerd Font", "Font Awesome 7 Free", sans-serif;
    font-size: 16px;
    min-height: 0;
    border: none;
    border-radius: 0;
}

window#waybar {
    background-color: transparent;
    background-image: ${sheen}linear-gradient(to bottom, ${rgba(t.panelTop)}, ${rgba(t.panelMid)} 40%, ${rgba(t.panelBottom)});
    color: ${rgba(text)};
    border-radius: ${R}px;
    border: ${t.bevel ? "none" : "1px solid " + rgba(t.panelBorder)};
    box-shadow: ${barShadow};
    transition-property: background-color, border-color;
    transition-duration: 0.35s;
}

window#waybar.hidden {
    opacity: 0.15;
}

tooltip {
    background-color: ${rgba(tipBg)};
    background-image: none;
    border: 1px solid ${rgba(darkTip ? Theme.alpha(WalColors.color5, 0.4) : t.panelBorder)};
    border-radius: ${t.bevel ? 0 : 13}px;
}

tooltip label {
    color: ${rgba(tipFg)};
    padding: 6px;
    text-shadow: none;
}

menu {
    background-color: ${rgba(Theme.alpha(t.dark ? t.panelMid : t.panelTop, 0.97))};
    border: 1px solid ${rgba(t.panelBorder)};
    border-radius: ${t.bevel ? 0 : 12}px;
    padding: 4px;
}

menu menuitem {
    color: ${rgba(text)};
    border-radius: ${p}px;
    padding: 4px 10px;
}

menu menuitem:hover {
    ${surface(t, t.fill || accent, 1)}
    color: ${rgba(t.selText)};
}

/* ── shared module chrome ──────────────────────────────────── */
#custom-archicon,
#submap,
#mpris,
#window,
#privacy,
#custom-idle,
#custom-dnd,
#custom-theme,
#tray,
#network,
#language,
#battery,
#clock,
#custom-power {
    padding: 0 10px;
    margin: 4px 1px;
    color: ${rgba(text)};
    background-color: transparent;
    background-image: none;
    border-radius: ${p}px;
    text-shadow: ${H(accent)};
    transition-property: background-color, color, box-shadow;
    transition-duration: 0.25s;
}

#custom-archicon:hover,
#mpris:hover,
#custom-idle:hover,
#custom-dnd:hover,
#custom-theme:hover,
#network:hover,
#language:hover,
#battery:hover,
#clock:hover {
    ${surface(t, t.fill || accent, 0.45)}
}

/* ── arch icon ─────────────────────────────────────────────── */
#custom-archicon {
    color: ${rgba(t.ink || accent)};
    font-size: 17px;
    padding: 0 12px 0 14px;
    margin-left: 2px;
    text-shadow: ${H(accent)};
}

#custom-archicon:hover {
    color: ${rgba(t.selText)};
}

/* ── workspaces ────────────────────────────────────────────── */
#workspaces {
    background-color: ${rgba(well)};
    border-radius: ${r}px;
    padding: 0 5px;
    margin: 5px 3px;
    ${t.bevel ? "box-shadow: inset 1px 1px " + rgba(t.shade) + ", inset -1px -1px " + rgba(t.light) + ";" : ""}
}

#workspaces button {
    padding: 0 4px;
    min-width: 0;
    color: ${rgba(Theme.alpha(text, 0.42))};
    background-color: transparent;
    background-image: none;
    border-radius: ${t.bevel ? 0 : 11}px;
    box-shadow: none;
    text-shadow: none;
    transition-property: color, background-color, padding;
    transition-duration: 0.3s;
    transition-timing-function: cubic-bezier(0.55, -0.68, 0.48, 1.68);
}

#workspaces button:hover {
    ${surface(t, t.fill || accent, 0.4)}
    color: ${rgba(text)};
    text-shadow: none;
}

#workspaces button.active {
    ${surface(t, t.fill || accent, 1)}
    color: ${rgba(t.selText)};
    padding: 0 13px;
    text-shadow: ${t.glow ? "0 0 4px " + rgba(accent) + ", 0 0 10px " + rgba(accent, 0.7) : t.raisedText ? "0 1px 1px rgba(0,0,0,0.45)" : "none"};
}

#workspaces button.urgent {
    background-image: none;
    background-color: ${rgba(t.crit, 0.22)};
    color: ${rgba(t.crit)};
    animation: blink 1s steps(2, start) infinite;
}

#workspaces button.empty {
    color: ${rgba(Theme.alpha(text, 0.24))};
}

/* ── submap / mode ─────────────────────────────────────────── */
#submap {
    color: ${rgba(t.warnInk || t.warn)};
    background-color: ${rgba(t.warn, 0.15)};
    animation: blink 1.6s ease-in-out infinite;
}

/* ── media ─────────────────────────────────────────────────── */
#mpris {
    color: ${rgba(t.dark ? t.accent2 : (t.ink || t.accent))};
    margin-left: 4px;
}

#mpris.paused {
    color: ${rgba(faint)};
    font-style: italic;
    text-shadow: none;
}

#mpris.stopped {
    color: transparent;
    background-color: transparent;
    padding: 0;
    margin: 0;
    min-width: 0;
}

/* ── focused window title ──────────────────────────────────── */
#window {
    color: ${rgba(Theme.alpha(text, 0.88))};
    font-style: italic;
    padding: 0 18px;
    background-color: ${rgba(well)};
    border-radius: ${t.bevel ? 0 : 11}px;
    ${t.bevel ? "box-shadow: inset 1px 1px " + rgba(t.shade) + ", inset -1px -1px " + rgba(t.light) + ";" : ""}
}

window#waybar.empty #window {
    background-color: transparent;
    box-shadow: none;
    color: ${rgba(Theme.alpha(text, 0.4))};
    text-shadow: none;
}

/* ── privacy ───────────────────────────────────────────────── */
#privacy {
    padding: 0 6px;
}

#privacy-item {
    padding: 0 5px;
    color: ${rgba(t.critInk || t.crit)};
    animation: pulse 2s ease-in-out infinite;
}

/* ── idle mode (coffee cup) ────────────────────────────────── */
#custom-idle {
    color: ${rgba(faint)};
    text-shadow: none;
}

#custom-idle.on {
    color: ${rgba(t.dark ? (t.warnInk || t.warn) : (t.ink || accent))};
    text-shadow: ${t.glow ? "0 0 6px " + rgba(t.warn, 0.8) + ", 0 0 14px " + rgba(t.warn, 0.45) : "none"};
}

/* ── do not disturb ────────────────────────────────────────── */
#custom-dnd {
    color: ${rgba(Theme.alpha(text, 0.78))};
}

#custom-dnd.dnd-on {
    color: ${rgba(t.critInk || t.crit)};
}

/* ── theme button ──────────────────────────────────────────── */
#custom-theme {
    color: ${rgba(t.ink || accent)};
}

/* ── tray ──────────────────────────────────────────────────── */
#tray {
    padding: 0 8px;
}

#tray > .passive {
    -gtk-icon-effect: dim;
}

#tray > .needs-attention {
    -gtk-icon-effect: highlight;
}

/* ── network · language ────────────────────────────────────── */
#network {
    color: ${rgba(text)};
}

#network.disconnected,
#network.linked {
    color: ${rgba(t.critInk || t.crit)};
}

#language {
    color: ${rgba(t.dim)};
    min-width: 34px;
}

/* ── battery ───────────────────────────────────────────────── */
#battery {
    color: ${rgba(text)};
}

#battery.good {
    color: ${rgba(t.okInk || t.ok)};
}

#battery.warning:not(.charging):not(.plugged) {
    color: ${rgba(t.warnInk || t.warn)};
}

#battery.critical:not(.charging):not(.plugged) {
    color: ${rgba(t.critInk || t.crit)};
    animation: blink 1s steps(2, start) infinite;
}

#battery.charging,
#battery.plugged {
    color: ${rgba(t.okInk || t.ok)};
}

/* ── clock ─────────────────────────────────────────────────── */
#clock {
    color: ${rgba(text)};
    font-weight: bold;
    padding: 0 12px;
}

/* ── power ─────────────────────────────────────────────────── */
#custom-power {
    color: ${rgba(t.crit, 0.9)};
    padding: 0 13px 0 11px;
    margin-right: 3px;
    text-shadow: none;
}

#custom-power:hover {
    color: #ffffff;
    background-image: none;
    background-color: ${rgba(t.crit, 0.85)};
    box-shadow: none;
}

@keyframes blink {
    to {
        opacity: 0.35;
    }
}

@keyframes pulse {
    0%   { opacity: 1.0; }
    50%  { opacity: 0.55; }
    100% { opacity: 1.0; }
}
`;
    }
}
