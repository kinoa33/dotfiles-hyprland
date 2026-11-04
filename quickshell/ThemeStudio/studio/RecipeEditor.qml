// edits one colour's recipe — where it starts and what is done to it:
//   from     a palette slot, another colour of the theme, or a fixed colour
//   lean     turn its hue toward a target (keeps the rice's tone)
//   vivid    more (or less) saturated and lighter/darker
//   tone     free hsl: shift the hue, scale or add saturation/lightness
//   lighter / darker   qt's lighter()/darker() by a factor
//   mix      blend toward other colours, in order
//   opacity  how see-through it is
// steps run in that order (common/Theme.qml recipe()). emits a new
// recipe object on every change; a recipe with no steps is saved as
// its plain source string.
import QtQuick
import QtQuick.Layouts
import "../common"

ColumnLayout {
    id: re
    property var th: Theme.t
    property var ed
    property var value                          // a recipe object or a plain reference
    property string self: ""
    signal changed(var recipe)

    spacing: 8
    Layout.fillWidth: true

    readonly property var rec: norm(value)
    function norm(v) {
        if (v && typeof v === "object") return JSON.parse(JSON.stringify(v));
        return { from: v === undefined || v === null || v === "" ? "bg" : String(v) };
    }
    function put(key, val) {
        const r = norm(value);
        if (val === undefined) delete r[key]; else r[key] = val;
        changed(r);
    }
    // the colour the steps start from, as an hsl hue (for lean's default)
    function hueOf(ref) {
        const q = Qt.color(String(ed ? ed.refValue(ref) : "#808080"));
        return q.hslHue < 0 ? 0 : q.hslHue;
    }

    readonly property var stepDefs: [
        { k: "lean",    l: "lean hue",  g: "\u{F0266}" },
        { k: "vivid",   l: "vivid",     g: "\u{F0768}" },
        { k: "tone",    l: "tone",      g: "\u{F0301}" },
        { k: "lighter", l: "lighter",   g: "\u{F0CE1}" },
        { k: "darker",  l: "darker",    g: "\u{F0CE1}" },
        { k: "mix",     l: "mix",       g: "\u{F0831}" },
        { k: "alpha",   l: "opacity",   g: "\u{F00B5}" }
    ]
    function addStep(k) {
        switch (k) {
        case "lean":    put("lean", [Math.round(hueOf(rec.from) * 100) / 100, 0.6, 1.0, 0.0]); break;
        case "vivid":   put("vivid", [1.3, 0.05]); break;
        case "tone":    put("tone", { hueShift: 0, satMul: 1, lightAdd: 0 }); break;
        case "lighter": put("lighter", 1.2); break;
        case "darker":  put("darker", 1.2); break;
        case "mix":     put("mix", (rec.mix || []).concat([["#ffffff", 0.2]])); break;
        case "alpha":   put("alpha", 0.8); break;
        }
    }

    // ── one step: a titled card with a remove button ─────────────
    component Step: Item {
        id: step
        property string title
        property string glyph
        signal removed()
        default property alias content: stepBody.data
        Layout.fillWidth: true
        implicitHeight: stepCol.implicitHeight + 16

        Rectangle {
            anchors.fill: parent
            radius: re.th.bevel ? 0 : re.th.radiusSm
            color: Theme.alpha(re.th.text, 0.04)
            border.width: 1
            border.color: Theme.alpha(re.th.text, 0.10)
        }
        ColumnLayout {
            id: stepCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text { text: step.glyph; color: re.th.ink; font { family: re.th.glyphFont; pixelSize: 13 } }
                Text {
                    Layout.fillWidth: true
                    text: step.title
                    color: re.th.text
                    font { family: re.th.font; pixelSize: 12; bold: true }
                }
                Text {
                    text: "\u{F0156}"
                    color: rmHover.hovered ? re.th.critInk : re.th.faint
                    font { family: re.th.glyphFont; pixelSize: 13 }
                    HoverHandler { id: rmHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: step.removed() }
                }
            }
            ColumnLayout {
                id: stepBody
                Layout.fillWidth: true
                spacing: 2
            }
        }
    }

    // ── from ─────────────────────────────────────────────────────
    Text {
        text: "from"
        color: re.th.dim
        font { family: re.th.font; pixelSize: 11 }
    }
    RefPicker {
        th: re.th
        ed: re.ed
        self: re.self
        value: re.rec.from
        onChosen: (ref) => re.put("from", ref)
    }

    // ── steps ────────────────────────────────────────────────────
    Step {
        visible: !!re.rec.lean
        title: "lean toward a hue"
        glyph: "\u{F0266}"
        onRemoved: re.put("lean", undefined)
        ValueSlider { th: re.th; Layout.fillWidth: true; label: "hue"; hue: true; value: re.rec.lean ? re.rec.lean[0] : 0; display: 360; decimals: 0; suffix: "°"; step: 0.005
                      onMoved: (v) => re.put("lean", [v, re.rec.lean[1], re.rec.lean[2], re.rec.lean[3]]) }
        ValueSlider { th: re.th; Layout.fillWidth: true; label: "amount"; value: re.rec.lean ? re.rec.lean[1] : 0; reset: 0.6
                      onMoved: (v) => re.put("lean", [re.rec.lean[0], v, re.rec.lean[2], re.rec.lean[3]]) }
        ValueSlider { th: re.th; Layout.fillWidth: true; label: "saturation ×"; value: re.rec.lean ? re.rec.lean[2] : 1; to: 3; reset: 1
                      onMoved: (v) => re.put("lean", [re.rec.lean[0], re.rec.lean[1], v, re.rec.lean[3]]) }
        ValueSlider { th: re.th; Layout.fillWidth: true; label: "lightness ±"; value: re.rec.lean ? re.rec.lean[3] : 0; from: -0.6; to: 0.6; reset: 0
                      onMoved: (v) => re.put("lean", [re.rec.lean[0], re.rec.lean[1], re.rec.lean[2], v]) }
    }
    Step {
        visible: !!re.rec.vivid
        title: "vivid"
        glyph: "\u{F0768}"
        onRemoved: re.put("vivid", undefined)
        ValueSlider { th: re.th; Layout.fillWidth: true; label: "saturation ×"; value: re.rec.vivid ? re.rec.vivid[0] : 1; to: 3; reset: 1
                      onMoved: (v) => re.put("vivid", [v, re.rec.vivid[1]]) }
        ValueSlider { th: re.th; Layout.fillWidth: true; label: "lightness ±"; value: re.rec.vivid ? re.rec.vivid[1] : 0; from: -0.6; to: 0.6; reset: 0
                      onMoved: (v) => re.put("vivid", [re.rec.vivid[0], v]) }
    }
    Step {
        id: toneStep
        visible: !!re.rec.tone
        title: "tone"
        glyph: "\u{F0301}"
        onRemoved: re.put("tone", undefined)
        readonly property var o: re.rec.tone || {}
        function set(k, v, dflt) {
            const t = Object.assign({}, re.rec.tone || {});
            if (v === dflt) delete t[k]; else t[k] = v;
            re.put("tone", t);
        }
        ValueSlider { th: re.th; Layout.fillWidth: true; label: "hue shift"; value: toneStep.o.hueShift || 0; from: -180; to: 180; step: 1; decimals: 0; suffix: "°"; reset: 0
                      onMoved: (v) => toneStep.set("hueShift", v, 0) }
        ValueSlider { th: re.th; Layout.fillWidth: true; label: "saturation ×"; value: toneStep.o.satMul === undefined ? 1 : toneStep.o.satMul; to: 3; reset: 1
                      onMoved: (v) => toneStep.set("satMul", v, 1) }
        ValueSlider { th: re.th; Layout.fillWidth: true; label: "saturation +"; value: toneStep.o.satAdd || 0; from: -1; to: 1; reset: 0
                      onMoved: (v) => toneStep.set("satAdd", v, 0) }
        ValueSlider { th: re.th; Layout.fillWidth: true; label: "lightness ×"; value: toneStep.o.lightMul === undefined ? 1 : toneStep.o.lightMul; to: 3; reset: 1
                      onMoved: (v) => toneStep.set("lightMul", v, 1) }
        ValueSlider { th: re.th; Layout.fillWidth: true; label: "lightness +"; value: toneStep.o.lightAdd || 0; from: -1; to: 1; reset: 0
                      onMoved: (v) => toneStep.set("lightAdd", v, 0) }
        ValueSlider { th: re.th; Layout.fillWidth: true; label: "light min"; value: toneStep.o.lightMin || 0; reset: 0
                      onMoved: (v) => toneStep.set("lightMin", v, 0) }
        ValueSlider { th: re.th; Layout.fillWidth: true; label: "light max"; value: toneStep.o.lightMax === undefined ? 1 : toneStep.o.lightMax; reset: 1
                      onMoved: (v) => toneStep.set("lightMax", v, 1) }
    }
    Step {
        visible: re.rec.lighter !== undefined
        title: "lighter"
        glyph: "\u{F0CE1}"
        onRemoved: re.put("lighter", undefined)
        ValueSlider { th: re.th; Layout.fillWidth: true; label: "factor"; value: re.rec.lighter || 1; from: 1; to: 3; reset: 1.2
                      onMoved: (v) => re.put("lighter", v) }
    }
    Step {
        visible: re.rec.darker !== undefined
        title: "darker"
        glyph: "\u{F0CE1}"
        onRemoved: re.put("darker", undefined)
        ValueSlider { th: re.th; Layout.fillWidth: true; label: "factor"; value: re.rec.darker || 1; from: 1; to: 3; reset: 1.2
                      onMoved: (v) => re.put("darker", v) }
    }
    Repeater {                                              // mix steps, one card each
        model: re.rec.mix || []
        Step {
            id: mixStep
            required property var modelData
            required property int index
            title: "mix " + (index + 1)
            glyph: "\u{F0831}"
            property bool picking: false
            onRemoved: {
                const m = (re.rec.mix || []).slice();
                m.splice(index, 1);
                re.put("mix", m.length ? m : undefined);
            }
            function setAt(ref, k) {
                const m = (re.rec.mix || []).map(x => x.slice());
                m[index] = [ref, k];
                re.put("mix", m);
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Swatch {
                    th: re.th
                    color: re.ed ? re.ed.refValue(mixStep.modelData[0]) : "transparent"
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: mixStep.picking = !mixStep.picking }
                }
                Text {
                    Layout.fillWidth: true
                    text: "toward " + mixStep.modelData[0] + (mixStep.picking ? "" : "   (click to change)")
                    elide: Text.ElideRight
                    color: re.th.dim
                    font { family: re.th.font; pixelSize: 11 }
                }
            }
            RefPicker {
                visible: mixStep.picking
                th: re.th
                ed: re.ed
                self: re.self
                value: String(mixStep.modelData[0])
                onChosen: (ref) => mixStep.setAt(ref, mixStep.modelData[1])
            }
            ValueSlider { th: re.th; Layout.fillWidth: true; label: "amount"; value: mixStep.modelData[1]; reset: 0.5
                          onMoved: (v) => mixStep.setAt(mixStep.modelData[0], v) }
        }
    }
    Step {
        visible: re.rec.alpha !== undefined && re.rec.alpha !== null
        title: "opacity"
        glyph: "\u{F00B5}"
        onRemoved: re.put("alpha", undefined)
        ValueSlider { th: re.th; Layout.fillWidth: true; label: "opacity"; value: re.rec.alpha === undefined ? 1 : re.rec.alpha; reset: 1
                      onMoved: (v) => re.put("alpha", v) }
    }

    // ── add a step ───────────────────────────────────────────────
    Flow {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: re.stepDefs.filter(d => d.k === "mix" || re.rec[d.k] === undefined)
            Btn {
                required property var modelData
                th: re.th
                size: 24
                glyph: "\u{F0415}"
                label: modelData.l
                onClicked: re.addStep(modelData.k)
            }
        }
    }
}
