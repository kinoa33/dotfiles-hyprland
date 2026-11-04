// the walrs (pywal) palette every widget is coloured from.
// it watches colors.json instead of polling it, so a rice re-colours
// running widgets (and the launcher daemon) without a restart.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: wal

    property var data: ({})

    readonly property string background: data.special ? data.special.background : "#1e1e2e"
    readonly property string foreground: data.special ? data.special.foreground : "#ffffff"

    readonly property string color0:  data.colors ? data.colors.color0  : "#000000"
    readonly property string color1:  data.colors ? data.colors.color1  : "#ff5555"
    readonly property string color2:  data.colors ? data.colors.color2  : "#50fa7b"
    readonly property string color3:  data.colors ? data.colors.color3  : "#f1fa8c"
    readonly property string color4:  data.colors ? data.colors.color4  : "#bd93f9"
    readonly property string color5:  data.colors ? data.colors.color5  : "#ff79c6"
    readonly property string color6:  data.colors ? data.colors.color6  : "#8be9fd"
    readonly property string color7:  data.colors ? data.colors.color7  : "#bbbbbb"
    readonly property string color8:  data.colors ? data.colors.color8  : "#44475a"
    readonly property string color9:  data.colors ? data.colors.color9  : color1
    readonly property string color10: data.colors ? data.colors.color10 : color2
    readonly property string color11: data.colors ? data.colors.color11 : color3
    readonly property string color12: data.colors ? data.colors.color12 : color4
    readonly property string color13: data.colors ? data.colors.color13 : color5
    readonly property string color14: data.colors ? data.colors.color14 : color6
    readonly property string color15: data.colors ? data.colors.color15 : color7

    // colorN by number (theme recipes say "color5")
    function slot(i) {
        return [color0, color1, color2, color3, color4, color5, color6, color7,
                color8, color9, color10, color11, color12, color13, color14, color15][i];
    }

    // the wallpaper walrs was last run on — the "rice" theme wears it
    readonly property string wallpaper: data.wallpaper || ""

    // semantic trio — same as waybar/style.css and hyprlock
    readonly property string ok:   "#79d17f"
    readonly property string warn: "#e0a458"
    readonly property string crit: "#ef5f6b"

    // walrs may replace the file rather than rewrite it, which can drop
    // an inotify watch — the launcher also calls this on every open
    function reload() { file.reload(); }

    FileView {
        id: file
        // QS_WAL_JSON: a test rig can feed a different palette
        path: Quickshell.env("QS_WAL_JSON") || (Quickshell.env("HOME") + "/.cache/wal/colors.json")
        blockLoading: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: wal.take(text())
    }
    function take(text) {
        try { wal.data = JSON.parse(text); } catch (e) {}
    }
    // read once, blocking, as the singleton is made: the first frame has the
    // real palette, not the fallback; watch only after (an early watch is
    // set on a still-empty path)
    Component.onCompleted: {
        take(file.text());
        file.watchChanges = true;
    }
}
