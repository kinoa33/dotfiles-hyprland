// tokdump · print every theme's tokens as one json line, then quit.
//   QS_WAL_JSON=tools/palettes/rose.json quickshell -p tools/tokdump
//   QS_DUMP_WIDGET=waybar   … as that widget wears them (per-widget overrides)
// tools/contrast.sh runs it over every test palette.
import QtQuick
import Quickshell
import "common"

ShellRoot {
    Timer {
        interval: 50
        running: true
        onTriggered: {
            const w = Quickshell.env("QS_DUMP_WIDGET") || "";
            const out = { _palette: WalColors.color5 + " on " + WalColors.background, _widget: w };
            for (const x of Theme.themes) {
                const t = Theme.tokens(x.id, w), o = {};
                for (const k in t) {
                    const v = t[k];
                    o[k] = (typeof v === "object" && v !== null && "r" in v) ? String(v) : v;
                }
                out[x.id] = o;
            }
            console.log("TOKENS " + JSON.stringify(out));
            Qt.quit();
        }
    }
}
