// ╔══════════════════════════════════════════════════════════════╗
// ║  control center · themed overlay (quickshell)                ║
// ║  toggle: Super+C, or click the window title in the bar       ║
// ║  tabs: controls · notifications · theme                      ║
// ║        (ctrl+tab / alt+1,2,3)                                ║
// ║                                                              ║
// ║  everything here is live:                                    ║
// ║    audio      pipewire events — no polling at all. pick the  ║
// ║               output, set each app's volume (mixer)          ║
// ║    media      mpris: art, seek bar, every player             ║
// ║    stats      one long-lived shell streaming a line per tick ║
// ║    controls   optimistic — the ui moves on click, the stream ║
// ║               reconciles a moment later                      ║
// ║    history    dunst's notification history: ⏎ / click shows  ║
// ║               one again, del forgets it                      ║
// ║                                                              ║
// ║  keys (controls)  ↑↓ volume · ←→ brightness · m mute         ║
// ║                   ␣ play/pause · , . previous/next           ║
// ║                   d dnd · w wifi · b bluetooth · i idle lock ║
// ╚══════════════════════════════════════════════════════════════╝
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Hyprland
import "common"

PanelWindow {
    id: root

    readonly property var th: Theme.t
    readonly property int margin: 44                    // shadow + pop-in room
    readonly property string home: Quickshell.env("HOME")
    property string tab: "controls"
    property string hint: ""                            // footer text while hovering a button

    // sized to the panel and hung from the bar's centre: the compositor
    // only re-blurs this patch. clicks elsewhere end the focus grab.
    anchors.top: true
    margins.top: Math.max(0, 56 - margin)              // bar: 6 + 37 + 13 gap
    implicitWidth: panel.width + margin * 2
    implicitHeight: panel.height + margin * 2
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-controlcenter"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // ── audio · reactive, never polled ───────────────────────────
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var nodes: Pipewire.nodes.values
    readonly property var sinks: nodes.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var streams: nodes.filter(n => n.audio && n.isStream && n.isSink)   // apps playing (output streams)
    PwObjectTracker { objects: [root.sink, root.source].concat(root.streams) }
    property string audioOpen: ""                       // "" · "outputs" · "mixer"

    function nodeLabel(n) {
        if (!n) return "";
        const p = n.properties || {};
        return p["application.name"] || n.nickname || n.description || n.name;
    }
    function nodeIcon(n) {
        const p = n.properties || {};
        const name = p["application.icon-name"] || p["application.process.binary"] || "";
        return name ? Quickshell.iconPath(name, true) : "";
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: Qt.quit()
    }

    Component.onCompleted: {
        Theme.widget = "controlcenter";
        historyProc.running = true;
        keys.forceActiveFocus();
    }

    function setTab(t) {
        root.tab = t;
        if (t === "theme") picker.forceActiveFocus();
        else keys.forceActiveFocus();
        if (t === "notifications") historyProc.running = true;
    }
    function cycleTab(d) {
        const k = ["controls", "notifications", "theme"];
        setTab(k[(k.indexOf(root.tab) + d + k.length) % k.length]);
    }
    Shortcut { sequence: "Ctrl+Tab"; context: Qt.ApplicationShortcut; onActivated: root.cycleTab(1) }
    Shortcut { sequence: "Ctrl+Shift+Tab"; context: Qt.ApplicationShortcut; onActivated: root.cycleTab(-1) }
    Shortcut { sequence: "Alt+1"; context: Qt.ApplicationShortcut; onActivated: root.setTab("controls") }
    Shortcut { sequence: "Alt+2"; context: Qt.ApplicationShortcut; onActivated: root.setTab("notifications") }
    Shortcut { sequence: "Alt+3"; context: Qt.ApplicationShortcut; onActivated: root.setTab("theme") }

    // ── streamed state ───────────────────────────────────────────
    property real cpuPct: 0
    property var cpuHist: []                            // the last 40 s, for the sparkline
    property real memPct: 0
    property real tempC: 0
    property real diskPct: 0
    property int batPct: -1
    property string batStatus: ""
    property string uptime: ""
    property int briPct: -1
    property bool dndOn: false
    property bool wifiOn: false
    property string wifiName: ""
    property bool btOn: false
    property string btName: ""
    property bool idleOn: true

    property var prevCpu: null

    function act(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    // ── optimistic holds ─────────────────────────────────────────
    // after you touch a control, ignore the stream for that field
    // briefly so the ui never snaps back to a stale reading
    property var holdUntil: ({})
    function hold(key, ms) {
        var h = root.holdUntil;
        h[key] = Date.now() + (ms || 1200);
        root.holdUntil = h;
    }
    function held(key) {
        return (root.holdUntil[key] || 0) > Date.now();
    }

    // ── actions ──────────────────────────────────────────────────
    function setVolume(v) {
        const vol = Math.max(0, Math.min(1, v));
        if (root.sink && root.sink.audio) {
            root.sink.audio.muted = false;
            root.sink.audio.volume = vol;          // lands on the device instantly
        } else {
            // no pipewire node bound — go through wireplumber instead
            root.act("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + Math.round(vol * 100) + "%");
        }
    }

    function toggleMute() {
        if (root.sink && root.sink.audio)
            root.sink.audio.muted = !root.sink.audio.muted;
        else
            root.act("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle");
    }

    function toggleMicMute() {
        if (root.source && root.source.audio)
            root.source.audio.muted = !root.source.audio.muted;
        else
            root.act("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle");
    }

    function setBrightness(v) {
        // floor of 3% so the screen never goes fully dark
        root.briPct = Math.round(Math.max(3, Math.min(100, v * 100)));
        root.hold("bri", 900);
        briWrite.restart();
    }
    Timer {
        id: briWrite
        interval: 50                                // coalesce a drag into few writes
        onTriggered: root.act("brightnessctl -q s " + root.briPct + "%")
    }

    function toggleDnd() {
        root.dndOn = !root.dndOn;                   // move now
        root.hold("dnd");
        root.act(root.home + "/.config/waybar/scripts/dnd.sh toggle");
    }
    function toggleWifi() {
        const want = !root.wifiOn;
        root.wifiOn = want;
        root.hold("wifi", 2500);
        root.act("nmcli radio wifi " + (want ? "on" : "off"));
    }
    function toggleBt() {
        const want = !root.btOn;
        root.btOn = want;
        root.hold("bt", 2500);
        root.act("bluetoothctl power " + (want ? "on" : "off"));
    }
    // same switch as waybar's coffee cup: on = lock after 30 min idle
    function toggleIdle() {
        root.idleOn = !root.idleOn;
        root.hold("idle");
        root.act(root.home + "/.config/hypr/scripts/idle.sh toggle");
    }

    // open another widget: close first, so a screenshot doesn't catch us
    function launch(cmd) {
        Quickshell.execDetached(["sh", "-c", "sleep 0.2; " + cmd]);
        Qt.quit();
    }

    // ── stats · one shell, streaming, no respawn ─────────────────
    Process {
        id: statsStream
        running: true
        command: ["sh", "-c",
            "while :; do " +
            "echo cpu $(grep '^cpu ' /proc/stat);" +
            "echo mem $(grep -E '^(MemTotal|MemAvailable)' /proc/meminfo | awk '{print $2}' | tr '\\n' ' ');" +
            "echo tmp $(cat /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input 2>/dev/null | head -1);" +
            "echo dsk $(df --output=pcent / | tail -1 | tr -d ' %');" +
            "echo bat $(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null) $(cat /sys/class/power_supply/BAT1/status 2>/dev/null);" +
            "echo upt $(awk '{print int($1)}' /proc/uptime);" +
            "echo brt $(brightnessctl -m 2>/dev/null | head -1 | cut -d, -f4 | tr -d %);" +
            "echo dnd $(dunstctl is-paused 2>/dev/null);" +
            "echo wif $(nmcli -t radio wifi 2>/dev/null);" +
            "echo ssi $(nmcli -t -f NAME,TYPE con show --active 2>/dev/null | awk -F: '$2 ~ /wireless/ {print $1; exit}');" +
            "echo blu $(bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2; exit}');" +
            "echo btd $(bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-);" +
            "echo idl $(cat \"${XDG_STATE_HOME:-$HOME/.local/state}/idle-mode/mode\" 2>/dev/null || echo on);" +
            "sleep 1; done"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.readStat(line)
        }
    }

    function readStat(line) {
        const p = line.trim().split(/\s+/);
        const rest = line.trim().slice(4);
        switch (p[0]) {
        case "cpu": {
            // line reads "cpu cpu <jiffies…>" — our label, then /proc/stat's
            const j = p.slice(2).map(Number);
            const idle = j[3] + (j[4] || 0);
            const total = j.reduce((a, b) => a + b, 0);
            if (root.prevCpu) {
                const dt = total - root.prevCpu.total;
                const di = idle - root.prevCpu.idle;
                if (dt > 0) {
                    root.cpuPct = Math.max(0, Math.min(100, 100 * (dt - di) / dt));
                    root.cpuHist = root.cpuHist.concat([root.cpuPct]).slice(-40);
                }
            }
            root.prevCpu = { total: total, idle: idle };
            break;
        }
        case "mem":
            if (p.length >= 3 && Number(p[1]) > 0)
                root.memPct = 100 * (1 - Number(p[2]) / Number(p[1]));
            break;
        case "tmp":
            if (p[1]) root.tempC = Number(p[1]) / 1000;
            break;
        case "dsk":
            if (p[1]) root.diskPct = Number(p[1]);
            break;
        case "bat":
            root.batPct = p[1] !== undefined && p[1] !== "" ? Number(p[1]) : -1;
            root.batStatus = p[2] || "";
            break;
        case "upt": {
            const s = Number(p[1]);
            root.uptime = Math.floor(s / 3600) + "h " + Math.floor((s % 3600) / 60) + "m";
            root.bootSec = s;
            break;
        }
        case "brt":
            if (!root.held("bri") && p[1] !== undefined && p[1] !== "")
                root.briPct = Number(p[1]);
            break;
        case "dnd":
            if (!root.held("dnd")) root.dndOn = p[1] === "true";
            break;
        case "wif":
            if (!root.held("wifi")) root.wifiOn = p[1] === "enabled";
            break;
        case "ssi":
            root.wifiName = rest;
            break;
        case "blu":
            if (!root.held("bt")) root.btOn = p[1] === "yes";
            break;
        case "btd":
            root.btName = rest;
            break;
        case "idl":
            if (!root.held("idle")) root.idleOn = p[1] !== "off";
            break;
        }
    }

    // battery time left / to full, from upower (seconds; 0 = unknown)
    readonly property real batSecs: {
        const d = UPower.displayDevice;
        if (!d || !d.ready) return 0;
        return root.batStatus === "Charging" ? d.timeToFull : root.batStatus === "Discharging" ? d.timeToEmpty : 0;
    }
    function hm(s) {
        s = Math.round(s / 60);
        return s >= 60 ? Math.floor(s / 60) + "h " + (s % 60) + "m" : s + "m";
    }

    // ── media · mpris, pushed — every player, not just the first ──
    readonly property var players: Mpris.players.values
    property string playerPick: ""                      // dbusName you chose; "" = the playing one
    readonly property MprisPlayer player: {
        const ps = root.players;
        if (!ps.length) return null;
        return ps.find(p => p.dbusName === root.playerPick) || ps.find(p => p.isPlaying) || ps[0];
    }
    function cyclePlayer() {
        const ps = root.players;
        if (ps.length < 2) return;
        const i = ps.indexOf(root.player);
        root.playerPick = ps[(i + 1) % ps.length].dbusName;
    }
    // position isn't pushed: ask for it while something plays
    Timer {
        running: root.player !== null && root.player.isPlaying && root.tab === "controls"
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player.positionChanged()
    }
    function clock(s) {
        s = Math.max(0, Math.floor(s));
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), x = s % 60;
        return (h ? h + ":" + (m < 10 ? "0" : "") : "") + m + ":" + (x < 10 ? "0" : "") + x;
    }

    // ── notification history (dunst) ─────────────────────────────
    property var history: []
    property int bootSec: 0
    property int noteSel: 0
    Process {
        id: historyProc
        command: ["sh", "-c", "awk '{print int($1)}' /proc/uptime; dunstctl history"]
        stdout: StdioCollector {
            onStreamFinished: {
                const nl = text.indexOf("\n");
                const now = Number(text.slice(0, nl));
                let rows = [];
                try { rows = JSON.parse(text.slice(nl + 1)).data[0]; } catch (e) {}
                const strip = s => String(s || "").replace(/<[^>]*>/g, "").replace(/&amp;/g, "&")
                                                 .replace(/&lt;/g, "<").replace(/&gt;/g, ">").trim();
                root.history = rows.map(r => ({
                    id: r.id.data,
                    app: strip(r.appname.data),
                    summary: strip(r.summary.data),
                    body: strip(r.body.data).replace(/\s+/g, " "),
                    icon: r.icon_path.data ? "file://" + r.icon_path.data : "",
                    urgent: r.urgency.data === "CRITICAL",
                    age: now - r.timestamp.data / 1e6
                }));
                root.noteSel = Math.min(root.noteSel, Math.max(0, root.history.length - 1));
            }
        }
    }
    function ago(s) {
        return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + "m" : s < 86400 ? Math.floor(s / 3600) + "h"
             : Math.floor(s / 86400) + "d";
    }
    function popNote(i) {                               // show it again (its actions work there)
        const n = root.history[i];
        if (!n) return;
        root.act("dunstctl history-pop " + n.id);
        root.history = root.history.filter(x => x !== n);
    }
    function forgetNote(i) {
        const n = root.history[i];
        if (!n) return;
        root.act("dunstctl history-rm " + n.id);
        root.history = root.history.filter(x => x !== n);
        root.noteSel = Math.min(root.noteSel, Math.max(0, root.history.length - 1));
    }
    property bool clearArmed: false
    function clearHistory() {
        if (!root.clearArmed) { root.clearArmed = true; disarm.restart(); return; }
        root.clearArmed = false;
        root.act("dunstctl history-clear");
        root.history = [];
    }

    // ── power · the destructive ones want a second click ─────────
    property string armed: ""
    Timer { id: disarm; interval: 3000; onTriggered: { root.armed = ""; root.clearArmed = false; } }
    function power(key, cmd, confirm) {
        if (confirm && root.armed !== key) { root.armed = key; disarm.restart(); return; }
        root.launch(cmd);
    }

    // ── keys ─────────────────────────────────────────────────────
    function controlsKey(ev) {
        const vol = root.sink?.audio?.volume ?? 0;
        switch (ev.key) {
        case Qt.Key_Up:    setVolume(vol + 0.05); break;
        case Qt.Key_Down:  setVolume(vol - 0.05); break;
        case Qt.Key_Right: if (root.briPct >= 0) setBrightness(root.briPct / 100 + 0.05); break;
        case Qt.Key_Left:  if (root.briPct >= 0) setBrightness(root.briPct / 100 - 0.05); break;
        case Qt.Key_M:     toggleMute(); break;
        case Qt.Key_Space: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying(); break;
        case Qt.Key_Comma: if (root.player && root.player.canGoPrevious) root.player.previous(); break;
        case Qt.Key_Period: if (root.player && root.player.canGoNext) root.player.next(); break;
        case Qt.Key_D:     toggleDnd(); break;
        case Qt.Key_W:     toggleWifi(); break;
        case Qt.Key_B:     toggleBt(); break;
        case Qt.Key_I:     toggleIdle(); break;
        default: return false;
        }
        return true;
    }
    function notesKey(ev) {
        const n = root.history.length;
        switch (ev.key) {
        case Qt.Key_Down:   root.noteSel = Math.min(n - 1, root.noteSel + 1); break;
        case Qt.Key_Up:     root.noteSel = Math.max(0, root.noteSel - 1); break;
        case Qt.Key_Return:
        case Qt.Key_Enter:  popNote(root.noteSel); break;
        case Qt.Key_Delete:
            if (ev.modifiers & Qt.ShiftModifier) clearHistory(); else forgetNote(root.noteSel);
            break;
        case Qt.Key_D:      toggleDnd(); break;
        default: return false;
        }
        noteList.positionViewAtIndex(root.noteSel, ListView.Contain);
        return true;
    }
    Item {
        id: keys
        focus: true
        Keys.onPressed: (ev) => {
            ev.accepted = root.tab === "controls" ? root.controlsKey(ev)
                        : root.tab === "notifications" ? root.notesKey(ev) : false;
        }
    }

    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; onActivated: {
        if (root.audioOpen !== "") root.audioOpen = "";
        else Qt.quit();
    } }

    // clicks in the transparent margin close it
    MouseArea { anchors.fill: parent; onClicked: Qt.quit() }

    // ── a slider that actually reads as one ──────────────────────
    component RiceSlider: Item {
        id: sl
        property real value: 0                    // 0 … 1
        property color accent: root.th.accent
        property real wheelStep: 0.02
        signal moved(real v)

        Layout.fillWidth: true
        implicitHeight: 24                        // generous hit area

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 8
            radius: root.th.surface === "block" ? 1 : 4
            color: Theme.alpha(root.th.text, 0.10)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, sl.value))
                height: parent.height
                radius: 4
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.alpha(sl.accent, 0.55) }
                    GradientStop { position: 1; color: sl.accent }
                }
                Behavior on width {
                    enabled: !drag.pressed
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(1, sl.value)) * (parent.width - width)
            width: 14; height: 14; radius: root.th.surface === "block" ? 2 : 7
            color: root.th.dark ? root.th.text : "white"
            border.width: 2
            border.color: sl.accent
            scale: drag.pressed ? 1.2 : (drag.containsMouse ? 1.1 : 1)
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuint } }
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            hoverEnabled: true
            function apply(mx) { sl.moved(Math.max(0, Math.min(1, mx / width))); }
            onPressed: (m) => apply(m.x)
            onPositionChanged: (m) => { if (pressed) apply(m.x); }
            onWheel: (w) => sl.moved(sl.value + (w.angleDelta.y > 0 ? sl.wheelStep : -sl.wheelStep))
        }
    }

    // ── a small text button: glyph + label, hover lights it ──────
    component LinkBtn: Item {
        id: lb
        property string glyph
        property string label
        property bool on: false
        property color ink: root.th.dim
        signal tapped()
        implicitWidth: lbRow.implicitWidth + 14
        implicitHeight: 24
        Surface {
            anchors.fill: parent
            radius: root.th.pillFull ? height / 2 : root.th.radiusSm
            tint: lb.on ? root.th.accent : root.th.text
            strength: lb.on ? 1 : lbHover.hovered ? 0.35 : 0
        }
        Row {
            id: lbRow
            anchors.centerIn: parent
            spacing: 5
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: lb.glyph !== ""
                text: lb.glyph
                color: lb.on ? root.th.selText : lb.ink
                font { family: root.th.glyphFont; pixelSize: 13 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: lb.label !== ""
                text: lb.label
                color: lb.on ? root.th.selText : lb.ink
                font { family: root.th.font; pixelSize: 11 }
            }
        }
        HoverHandler { id: lbHover }
        TapHandler { onTapped: lb.tapped() }
    }

    // ── the glass panel, hanging from the bar's centre ───────────
    ThemedPanel {
        id: panel
        title: "control center"
        x: root.margin
        y: root.margin
        width: 440
        height: contentCol.implicitHeight + 36 + topInset

        opacity: 0
        scale: 0.97
        Component.onCompleted: { opacity = 1; scale = 1; }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
        Behavior on scale   { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

        MouseArea { anchors.fill: parent; onClicked: if (root.tab !== "theme") keys.forceActiveFocus() }

        ColumnLayout {
            id: contentCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 18
            anchors.topMargin: 18 + panel.topInset
            spacing: 12

            // ── header ───────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Emblem {
                    glyph: root.tab === "theme" ? "\u{F03D8}" : root.tab === "notifications" ? "\u{F009A}" : "\u{F0128}"
                    size: 34
                }
                Text {
                    text: root.tab === "theme" ? "theme" : root.tab === "notifications" ? "notifications" : "control center"
                    color: root.th.text
                    font { family: root.th.font; pixelSize: 17; bold: true }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "up " + root.uptime
                    color: root.th.faint
                    font { family: root.th.font; pixelSize: 12 }
                }
            }

            TabBar {
                model: [
                    { key: "controls", label: "controls", glyph: "\u{F062E}" },
                    { key: "notifications", label: root.history.length ? "notifications  " + root.history.length : "notifications",
                      glyph: root.dndOn ? "\u{F009B}" : "\u{F009A}" },
                    { key: "theme", label: "theme", glyph: "\u{F03D8}" }
                ]
                current: root.tab
                onPicked: (key) => root.setTab(key)
            }

            ThemePicker {
                id: picker
                visible: root.tab === "theme"
                Layout.fillWidth: true
                Layout.preferredHeight: 470
            }

            // ══ notifications ════════════════════════════════════
            ColumnLayout {
                visible: root.tab === "notifications"
                Layout.fillWidth: true
                Layout.preferredHeight: 470
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        Layout.fillWidth: true
                        text: root.history.length ? root.history.length + " in the history" : ""
                        color: root.th.faint
                        font { family: root.th.font; pixelSize: 12 }
                    }
                    LinkBtn {
                        glyph: root.dndOn ? "\u{F009B}" : "\u{F009A}"
                        label: root.dndOn ? "do not disturb · on" : "do not disturb"
                        on: root.dndOn
                        onTapped: root.toggleDnd()
                    }
                    LinkBtn {
                        visible: root.history.length > 0
                        glyph: "\u{F0156}"
                        label: root.clearArmed ? "click again to clear" : "clear all"
                        ink: root.th.critInk
                        onTapped: root.clearHistory()
                    }
                }

                Well {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: noteList
                        anchors.fill: parent
                        anchors.margins: 6
                        clip: true
                        spacing: 2
                        model: root.history
                        boundsBehavior: Flickable.StopAtBounds
                        currentIndex: root.noteSel

                        delegate: Item {
                            id: note
                            required property var modelData
                            required property int index
                            readonly property bool sel: index === root.noteSel
                            width: ListView.view.width
                            height: noteCol.implicitHeight + 16

                            Surface {
                                anchors.fill: parent
                                strength: note.sel ? 1 : noteHover.hovered ? 0.35 : 0
                                tint: note.modelData.urgent ? root.th.crit : root.th.accent
                                tick: note.sel
                            }
                            HoverHandler { id: noteHover }
                            TapHandler {
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onTapped: (p, b) => {
                                    root.noteSel = note.index;
                                    if (b === Qt.MiddleButton) root.forgetNote(note.index); else root.popNote(note.index);
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Item {
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 8
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    IconImage {
                                        id: noteIcon
                                        anchors.fill: parent
                                        source: note.modelData.icon
                                        visible: note.modelData.icon !== "" && status === Image.Ready
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: !noteIcon.visible
                                        text: "\u{F009A}"
                                        color: note.sel ? root.th.selText : note.modelData.urgent ? root.th.critInk : root.th.ink
                                        font { family: root.th.glyphFont; pixelSize: 18 }
                                    }
                                }

                                ColumnLayout {
                                    id: noteCol
                                    Layout.fillWidth: true
                                    Layout.topMargin: 8
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            Layout.fillWidth: true
                                            text: note.modelData.summary || note.modelData.app
                                            elide: Text.ElideRight
                                            color: note.sel ? root.th.selText : root.th.text
                                            font { family: root.th.font; pixelSize: 13; bold: true }
                                        }
                                        Text {
                                            text: note.modelData.app + "  ·  " + root.ago(note.modelData.age)
                                            color: note.sel ? root.th.selDim : root.th.faint
                                            font { family: root.th.font; pixelSize: 10 }
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        visible: text !== "" && text !== note.modelData.summary
                                        text: note.modelData.body
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        color: note.sel ? root.th.selDim : root.th.dim
                                        font { family: root.th.font; pixelSize: 11 }
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 8
                                    text: "\u{F0156}"
                                    visible: noteHover.hovered
                                    color: note.sel ? root.th.selText : Theme.alpha(root.th.critInk, xHover.hovered ? 1 : 0.75)
                                    font { family: root.th.glyphFont; pixelSize: 13 }
                                    HoverHandler { id: xHover }
                                    TapHandler { onTapped: root.forgetNote(note.index) }
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            visible: root.history.length === 0
                            spacing: 12
                            Emblem {
                                anchors.horizontalCenter: parent.horizontalCenter
                                glyph: "\u{F009A}"
                                opacity: 0.75
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: historyProc.running ? "reading…" : "no notifications"
                                color: root.th.faint
                                font { family: root.th.font; pixelSize: 13; italic: true }
                            }
                        }
                    }
                }
            }

            // ══ controls ═════════════════════════════════════════
            ColumnLayout {
            visible: root.tab === "controls"
            Layout.fillWidth: true
            spacing: 12

            // ── stat rows ────────────────────────────────────────
            component StatRow: RowLayout {
                property string icon
                property string label
                property real value          // 0-100
                property string valueText
                property string note
                property color accent
                property var spark: []       // recent values 0-100, drawn behind the bar
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: icon
                    color: accent
                    font { family: root.th.glyphFont; pixelSize: 14 }
                    Layout.preferredWidth: 20
                }
                Text {
                    text: label
                    color: Theme.alpha(root.th.text, 0.75)
                    font { family: root.th.font; pixelSize: 13 }
                    Layout.preferredWidth: 42
                }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 14

                    Row {                    // sparkline: the last 40 s, one sliver each
                        id: sparkRow
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        spacing: 1
                        visible: spark.length > 1
                        readonly property real w: (parent.width + 1) / 40 - 1
                        Repeater {
                            model: spark
                            Rectangle {
                                required property real modelData
                                anchors.bottom: parent.bottom
                                width: sparkRow.w
                                height: Math.max(1, 12 * modelData / 100)
                                color: Theme.alpha(accent, 0.22)
                            }
                        }
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        implicitHeight: 6
                        radius: 3
                        color: Theme.alpha(root.th.text, 0.08)
                        Rectangle {
                            width: parent.width * Math.min(1, Math.max(0, value / 100))
                            height: parent.height
                            radius: 3
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.alpha(accent, 0.55) }
                                GradientStop { position: 1; color: accent }
                            }
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                        }
                    }
                }
                Text {
                    visible: note !== ""
                    text: note
                    color: root.th.faint
                    font { family: root.th.font; pixelSize: 11 }
                }
                Text {
                    text: valueText
                    color: root.th.text
                    font { family: root.th.font; pixelSize: 13 }
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 44
                }
            }

            StatRow { icon: "\u{F0EE0}"; label: "cpu"; value: root.cpuPct; valueText: Math.round(root.cpuPct) + "%"; accent: root.th.accent; spark: root.cpuHist }
            StatRow { icon: "\u{F035B}"; label: "ram"; value: root.memPct; valueText: Math.round(root.memPct) + "%"; accent: root.th.accent2 }
            StatRow {
                icon: "\u{F050F}"; label: "temp"
                value: root.tempC
                valueText: Math.round(root.tempC) + "°"
                accent: root.tempC >= 85 ? root.th.crit : root.th.ok
            }
            StatRow { icon: "\u{F02CA}"; label: "disk"; value: root.diskPct; valueText: Math.round(root.diskPct) + "%"; accent: root.th.dim }
            StatRow {
                visible: root.batPct >= 0
                icon: root.batStatus === "Charging" ? "\u{F0084}" : "\u{F0079}"
                label: "bat"
                value: root.batPct < 0 ? 0 : root.batPct
                valueText: (root.batPct < 0 ? "?" : root.batPct) + "%"
                note: root.batSecs > 0 ? root.hm(root.batSecs) + (root.batStatus === "Charging" ? " to full" : " left") : ""
                accent: root.batStatus === "Charging" ? root.th.ok
                      : root.batPct <= 20 ? root.th.crit : root.th.ok
            }

            // ── divider ──────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.alpha(root.th.accent, 0.15)
            }

            // ── volume ───────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: (root.sink?.audio?.muted ?? false) ? "\u{F075F}" : "\u{F057E}"
                    color: (root.sink?.audio?.muted ?? false)
                        ? Theme.alpha(root.th.text, 0.35)
                        : root.th.accent
                    font { family: root.th.glyphFont; pixelSize: 17 }
                    Layout.preferredWidth: 22
                    TapHandler { onTapped: root.toggleMute() }
                }

                RiceSlider {
                    accent: root.th.accent
                    value: root.sink?.audio?.volume ?? 0
                    onMoved: (v) => root.setVolume(v)
                }

                Text {
                    text: Math.round((root.sink?.audio?.volume ?? 0) * 100) + "%"
                    color: root.th.text
                    font { family: root.th.font; pixelSize: 13 }
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 40
                }
            }

            // output · mixer · mic
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: -4
                spacing: 4

                LinkBtn {
                    Layout.fillWidth: true
                    Layout.maximumWidth: implicitWidth
                    glyph: "\u{F04C3}"
                    label: (root.sink ? root.nodeLabel(root.sink) : "no output device")
                           + (root.sinks.length > 1 ? "  " + (root.audioOpen === "outputs" ? "\u{F0143}" : "\u{F0140}") : "")
                    on: root.audioOpen === "outputs"
                    clip: true
                    onTapped: if (root.sinks.length > 1) root.audioOpen = root.audioOpen === "outputs" ? "" : "outputs"
                }
                Item { Layout.fillWidth: true }
                LinkBtn {
                    visible: root.streams.length > 0
                    glyph: "\u{F08C6}"
                    label: root.streams.length + (root.streams.length === 1 ? " app" : " apps")
                    on: root.audioOpen === "mixer"
                    onTapped: root.audioOpen = root.audioOpen === "mixer" ? "" : "mixer"
                }
                LinkBtn {
                    glyph: (root.source?.audio?.muted ?? true) ? "\u{F036D}" : "\u{F036C}"
                    label: "mic"
                    ink: (root.source?.audio?.muted ?? true) ? Theme.alpha(root.th.text, 0.4) : root.th.okInk
                    onTapped: root.toggleMicMute()
                }
            }

            // the outputs, to switch to one
            ColumnLayout {
                visible: root.audioOpen === "outputs"
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: root.audioOpen === "outputs" ? root.sinks : []
                    delegate: Item {
                        id: out
                        required property var modelData
                        readonly property bool cur: modelData === root.sink
                        Layout.fillWidth: true
                        implicitHeight: 30
                        Surface {
                            anchors.fill: parent
                            strength: out.cur ? 1 : outHover.hovered ? 0.35 : 0
                            tint: root.th.accent
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 32
                            anchors.rightMargin: 10
                            Text {
                                Layout.fillWidth: true
                                text: out.modelData.description || out.modelData.name
                                elide: Text.ElideRight
                                color: out.cur ? root.th.selText : root.th.text
                                font { family: root.th.font; pixelSize: 12 }
                            }
                            Text {
                                visible: out.cur
                                text: "\u{F012C}"
                                color: root.th.selText
                                font { family: root.th.glyphFont; pixelSize: 13 }
                            }
                        }
                        HoverHandler { id: outHover }
                        TapHandler {
                            onTapped: {
                                Pipewire.preferredDefaultAudioSink = out.modelData;
                                root.audioOpen = "";
                            }
                        }
                    }
                }
            }

            // the mixer: a slider per app that's playing
            ColumnLayout {
                visible: root.audioOpen === "mixer"
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: root.audioOpen === "mixer" ? root.streams : []
                    delegate: RowLayout {
                        id: app
                        required property var modelData
                        readonly property bool muted: modelData.audio ? modelData.audio.muted : false
                        Layout.fillWidth: true
                        spacing: 10
                        Item {
                            Layout.preferredWidth: 22
                            implicitHeight: 22
                            IconImage {
                                id: appIcon
                                anchors.fill: parent
                                source: root.nodeIcon(app.modelData)
                                visible: status === Image.Ready
                                opacity: app.muted ? 0.4 : 1
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !appIcon.visible
                                text: "\u{F08C6}"
                                color: app.muted ? Theme.alpha(root.th.text, 0.35) : root.th.accent2
                                font { family: root.th.glyphFont; pixelSize: 15 }
                            }
                            TapHandler { onTapped: if (app.modelData.audio) app.modelData.audio.muted = !app.muted }
                        }
                        Text {
                            Layout.preferredWidth: 92
                            text: root.nodeLabel(app.modelData)
                            elide: Text.ElideRight
                            color: app.muted ? root.th.faint : root.th.dim
                            font { family: root.th.font; pixelSize: 11 }
                        }
                        RiceSlider {
                            accent: root.th.accent2
                            value: app.modelData.audio ? app.modelData.audio.volume : 0
                            onMoved: (v) => {
                                if (!app.modelData.audio) return;
                                app.modelData.audio.muted = false;
                                app.modelData.audio.volume = v;
                            }
                        }
                        Text {
                            text: Math.round((app.modelData.audio ? app.modelData.audio.volume : 0) * 100) + "%"
                            color: root.th.text
                            font { family: root.th.font; pixelSize: 12 }
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: 40
                        }
                    }
                }
            }

            // ── brightness ───────────────────────────────────────
            RowLayout {
                visible: root.briPct >= 0
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "\u{F00DF}"
                    color: root.th.warn
                    font { family: root.th.glyphFont; pixelSize: 16 }
                    Layout.preferredWidth: 22
                }

                RiceSlider {
                    accent: root.th.warn
                    value: root.briPct / 100
                    onMoved: (v) => root.setBrightness(v)
                }

                Text {
                    text: root.briPct + "%"
                    color: root.th.text
                    font { family: root.th.font; pixelSize: 13 }
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 40
                }
            }

            // ── divider ──────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.alpha(root.th.accent, 0.15)
            }

            // ── media · art, track, seek bar, controls ───────────
            RowLayout {
                visible: root.player !== null
                Layout.fillWidth: true
                spacing: 12

                ClippingRectangle {
                    implicitWidth: 64
                    implicitHeight: 64
                    radius: root.th.radiusSm
                    color: Theme.alpha(root.th.text, 0.06)
                    Image {
                        id: art
                        anchors.fill: parent
                        source: root.player ? root.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(128, 128)
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !art.visible
                        text: "\u{F075A}"
                        color: root.player && root.player.isPlaying ? root.th.accent2 : root.th.faint
                        font { family: root.th.glyphFont; pixelSize: 26 }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            Layout.fillWidth: true
                            text: root.player ? (root.player.trackTitle || root.player.identity) : ""
                            elide: Text.ElideRight
                            color: root.th.text
                            font { family: root.th.font; pixelSize: 13; bold: true }
                        }
                        LinkBtn {                    // which player · click for the next one
                            visible: root.players.length > 1
                            label: root.player ? root.player.identity + "  " + (root.players.indexOf(root.player) + 1) + "/" + root.players.length : ""
                            onTapped: root.cyclePlayer()
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.player ? (root.player.trackArtist || (root.players.length > 1 ? "" : root.player.identity)) : ""
                        elide: Text.ElideRight
                        color: Theme.alpha(root.th.text, 0.55)
                        font { family: root.th.font; pixelSize: 11 }
                    }

                    // seek bar · click or drag to jump (when the player allows it)
                    RowLayout {
                        visible: root.player !== null && root.player.lengthSupported && root.player.length > 0
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: root.player ? root.clock(root.player.position) : ""
                            color: root.th.faint
                            font { family: root.th.font; pixelSize: 10 }
                        }
                        Item {
                            id: seek
                            Layout.fillWidth: true
                            implicitHeight: 14
                            readonly property real frac: root.player && root.player.length > 0
                                ? Math.max(0, Math.min(1, root.player.position / root.player.length)) : 0
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4
                                radius: 2
                                color: Theme.alpha(root.th.text, 0.10)
                                Rectangle {
                                    width: parent.width * seek.frac
                                    height: parent.height
                                    radius: 2
                                    color: root.th.accent2
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: root.player !== null && root.player.canSeek
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                function jump(mx) { root.player.position = Math.max(0, Math.min(1, mx / width)) * root.player.length; }
                                onPressed: (m) => jump(m.x)
                                onPositionChanged: (m) => { if (pressed) jump(m.x); }
                            }
                        }
                        Text {
                            text: root.player ? root.clock(root.player.length) : ""
                            color: root.th.faint
                            font { family: root.th.font; pixelSize: 10 }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        component MediaBtn: Text {
                            property bool can: true
                            signal pressed()
                            property alias hovered: mbHover.hovered
                            opacity: can ? 1 : 0.3
                            color: hovered && can ? root.th.accent : Theme.alpha(root.th.text, 0.7)
                            font { family: root.th.glyphFont; pixelSize: 16 }
                            HoverHandler { id: mbHover }
                            TapHandler { onTapped: if (parent.can) parent.pressed() }
                        }

                        MediaBtn {
                            text: "\u{F04AE}"
                            can: root.player !== null && root.player.canGoPrevious
                            onPressed: root.player.previous()
                        }
                        MediaBtn {
                            text: root.player && root.player.isPlaying ? "\u{F03E4}" : "\u{F040A}"
                            can: root.player !== null && root.player.canTogglePlaying
                            font.pixelSize: 20
                            onPressed: root.player.togglePlaying()
                        }
                        MediaBtn {
                            text: "\u{F04AD}"
                            can: root.player !== null && root.player.canGoNext
                            onPressed: root.player.next()
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ── quick toggles · dnd / wifi / bluetooth / idle ────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                component TogglePill: Item {
                    id: tp
                    property string icon
                    property string label
                    property bool on
                    signal toggled()
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1                 // equal shares, whatever the label
                    implicitHeight: 46

                    Surface {
                        anchors.fill: parent
                        radius: root.th.radiusSm + 2
                        tint: tp.on ? root.th.accent : root.th.text
                        strength: tp.on ? 1 : (tpHover.hovered ? 0.4 : 0.2)
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 1
                        Item { Layout.fillHeight: true }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: icon
                            color: on ? root.th.selText : root.th.faint
                            font { family: root.th.glyphFont; pixelSize: 16 }
                        }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: label
                            elide: Text.ElideRight
                            color: on ? root.th.selText : root.th.faint
                            font { family: root.th.font; pixelSize: 10 }
                        }
                        Item { Layout.fillHeight: true }
                    }
                    HoverHandler { id: tpHover }
                    TapHandler { onTapped: tp.toggled() }
                }

                TogglePill {
                    icon: on ? "\u{F009B}" : "\u{F009A}"; label: "dnd"; on: root.dndOn
                    onToggled: root.toggleDnd()
                }
                TogglePill {
                    icon: on ? "\u{F05A9}" : "\u{F05AA}"; label: on && root.wifiName ? root.wifiName : "wifi"; on: root.wifiOn
                    onToggled: root.toggleWifi()
                }
                TogglePill {
                    icon: on ? "\u{F00AF}" : "\u{F00B2}"; label: on && root.btName ? root.btName : "bluetooth"; on: root.btOn
                    onToggled: root.toggleBt()
                }
                TogglePill {
                    icon: on ? "\u{F0176}" : "\u{F06CA}"; label: "idle lock"; on: root.idleOn
                    onToggled: root.toggleIdle()
                }
            }

            // ── the other widgets · power ────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                component IconBtn: Item {
                    id: ib
                    property string glyph
                    property string tip
                    property bool hot: false                 // armed: click again
                    property color ink: root.th.dim
                    signal tapped()
                    Layout.fillWidth: true
                    implicitHeight: 34
                    Surface {
                        anchors.fill: parent
                        radius: root.th.radiusSm
                        tint: ib.hot ? root.th.crit : root.th.text
                        strength: ib.hot ? 1 : ibHover.hovered ? 0.4 : 0.12
                    }
                    Text {
                        anchors.centerIn: parent
                        text: ib.glyph
                        color: ib.hot ? root.th.selText : ibHover.hovered ? root.th.text : ib.ink
                        font { family: root.th.glyphFont; pixelSize: 15 }
                    }
                    HoverHandler {
                        id: ibHover
                        onHoveredChanged: root.hint = hovered ? ib.tip : (root.hint === ib.tip ? "" : root.hint)
                    }
                    TapHandler { onTapped: ib.tapped() }
                }

                IconBtn { glyph: "\u{F0100}"; tip: "screenshot"; onTapped: root.launch("exec quickshell -p \"$HOME/.config/quickshell/HyprQuickFrame\" -n") }
                IconBtn { glyph: "\u{F0E09}"; tip: "wallpapers"; onTapped: root.launch("exec \"$HOME/.config/hypr/scripts/qs-toggle.sh\" WallPicker") }
                IconBtn { glyph: "\u{F0132}"; tip: "todo"; onTapped: root.launch("exec \"$HOME/.config/hypr/scripts/qs-toggle.sh\" TodoWidget") }
                IconBtn { glyph: "\u{F014C}"; tip: "clipboard"; onTapped: root.launch("exec \"$HOME/.config/hypr/scripts/launcher.sh\" clip") }
                IconBtn { glyph: "\u{F03D8}"; tip: "theme studio"; onTapped: root.launch("exec \"$HOME/.config/hypr/scripts/theme-studio.sh\"") }
                Rectangle {
                    implicitWidth: 1
                    implicitHeight: 22
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    color: Theme.alpha(root.th.text, 0.15)
                }
                IconBtn { glyph: "\u{F033E}"; tip: "lock"; onTapped: root.power("lock", "loginctl lock-session", false) }
                IconBtn { glyph: "\u{F0904}"; tip: "suspend"; onTapped: root.power("suspend", "systemctl suspend", false) }
                IconBtn {
                    glyph: "\u{F05FD}"; tip: "log out"; hot: root.armed === "logout"
                    onTapped: root.power("logout", "hyprctl dispatch exit", true)
                }
                IconBtn {
                    glyph: "\u{F0709}"; tip: "reboot"; hot: root.armed === "reboot"
                    onTapped: root.power("reboot", "systemctl reboot", true)
                }
                IconBtn {
                    glyph: "\u{F0425}"; tip: "shut down"; hot: root.armed === "poweroff"; ink: root.th.critInk
                    onTapped: root.power("poweroff", "systemctl poweroff", true)
                }
            }
            }

            // ── footer · what a button does, or the keys ─────────
            // the hints sit in a clipped strip: wide fonts cut them
            // off instead of pushing the panel wider
            RowLayout {
                visible: root.tab !== "theme"
                Layout.fillWidth: true
                spacing: 12

                Item {
                    Layout.fillWidth: true
                    implicitHeight: hintRow.implicitHeight
                    clip: true
                    Row {
                        id: hintRow
                        spacing: 12
                        Text {
                            visible: root.armed !== ""
                            text: "click again to " + (root.armed === "poweroff" ? "shut down" : root.armed === "logout" ? "log out" : root.armed)
                            color: root.th.critInk
                            font { family: root.th.font; pixelSize: 12; bold: true }
                        }
                        Text {
                            visible: root.armed === "" && root.hint !== ""
                            text: root.hint
                            color: root.th.text
                            font { family: root.th.font; pixelSize: 12 }
                        }
                        Keycap { visible: root.tab === "controls" && root.armed === "" && root.hint === ""; keys: "↑↓"; label: "volume" }
                        Keycap { visible: root.tab === "controls" && root.armed === "" && root.hint === "" && root.briPct >= 0; keys: "←→"; label: "light" }
                        Keycap { visible: root.tab === "controls" && root.armed === "" && root.hint === ""; keys: "m"; label: "mute" }
                        Keycap { visible: root.tab === "controls" && root.armed === "" && root.hint === "" && root.player !== null; keys: "␣"; label: "play" }
                        Keycap { visible: root.tab === "notifications" && root.history.length > 0; keys: "⏎"; label: "show again" }
                        Keycap { visible: root.tab === "notifications" && root.history.length > 0; keys: "del"; label: "forget" }
                        Keycap { visible: root.tab === "notifications"; keys: "d"; label: "dnd" }
                    }
                }
                Keycap { keys: "esc"; label: "close" }
            }
        }
    }
}
