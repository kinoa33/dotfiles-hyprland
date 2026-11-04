// how readable the theme is: every kind of text, judged (wcag contrast)
// over the glass on a dark AND a light wallpaper — the worst case shows.
// "auto" marks colours the contrast solver had to move from your recipe.
import QtQuick
import QtQuick.Layouts
import "../common"

ColumnLayout {
    id: cr
    property var th: Theme.t
    property var tok                            // the tokens being judged
    property var raw                            // same theme with contrast "off" (the recipe as written)
    spacing: 4
    Layout.fillWidth: true

    function over(top, bottom) { return Theme.over(top, bottom); }
    function worstOn(c, bgs) {
        let w = 99;
        for (const b of bgs) w = Math.min(w, Theme.contrast(over(c, b), b));
        return w;
    }
    readonly property var rows: {
        const t = cr.tok;
        if (!t) return [];
        const panels = Theme.backdrops.map(b => over(t.panelMid, b));
        const wells = panels.map(p => over(t.well, p));
        const under = wells.concat(panels);
        const sel = wells.map(w => Theme.selFill(t, t.fill, w));
        const moved = (k) => cr.raw && String(cr.raw[k]) !== String(t[k]);
        return [
            { name: "text",            v: worstOn(t.text, under),  min: 4.5, auto: moved("text") },
            { name: "dim text",        v: worstOn(t.dim, under),   min: 3.0 },
            { name: "faint hints",     v: worstOn(t.faint, under), min: 2.2 },
            { name: "accent as text",  v: worstOn(t.ink, under),   min: 3.0, auto: String(t.ink) !== String(Qt.color(String(t.accent))) },
            { name: "search match",    v: worstOn(t.match, under), min: 3.0 },
            { name: "selected text",   v: Math.min(...sel.map(f => Theme.contrast(t.selText, f))), min: 4.5, auto: moved("selText") || String(t.fill) !== String(Qt.color(String(t.accent))) },
            { name: "ok / warn / crit", v: Math.min(worstOn(t.okInk, under), worstOn(t.warnInk, under), worstOn(t.critInk, under)), min: 3.0 }
        ];
    }
    readonly property int fails: rows.filter(r => r.v < r.min).length

    Repeater {
        model: cr.rows
        RowLayout {
            required property var modelData
            readonly property bool pass: modelData.v >= modelData.min
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: pass ? "\u{F012C}" : "\u{F0028}"
                color: pass ? cr.th.okInk : cr.th.critInk
                font { family: cr.th.glyphFont; pixelSize: 13 }
            }
            Text {
                Layout.fillWidth: true
                text: modelData.name
                color: cr.th.text
                font { family: cr.th.font; pixelSize: 12 }
            }
            Text {
                visible: !!modelData.auto
                text: "auto"
                color: cr.th.faint
                font { family: cr.th.font; pixelSize: 10; italic: true }
            }
            Text {
                text: modelData.v.toFixed(1) + " : 1"
                color: pass ? cr.th.dim : cr.th.critInk
                font { family: cr.th.font; pixelSize: 12 }
            }
        }
    }
}
