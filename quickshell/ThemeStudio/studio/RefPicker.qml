// choose where a colour comes from:
//   palette  a walrs slot (bg, fg, color0…15, ok/warn/crit) — follows the rice
//   theme    another colour of this theme ("@accent", "@aqua" …)
//   fixed    one exact colour, the same on every wallpaper
// `ed` is the studio editor (colour lookups for the swatches)
import QtQuick
import QtQuick.Layouts
import "../common"

ColumnLayout {
    id: rp
    property var th: Theme.t
    property var ed
    property string value: "bg"
    property string self: ""                    // the colour being edited: not offered as a source
    signal chosen(string ref)

    readonly property string kind: value.charAt(0) === "@" ? "theme"
                                 : Theme.paletteSlots.indexOf(value) >= 0 ? "palette" : "fixed"
    property string tab: kind
    onValueChanged: tab = kind
    spacing: 8
    Layout.fillWidth: true

    RowLayout {
        spacing: 6
        Repeater {
            model: [ { k: "palette", l: "palette", g: "󰏘" }, { k: "theme", l: "theme colour", g: "󰌁" }, { k: "fixed", l: "fixed", g: "󰈊" } ]
            Btn {
                required property var modelData
                th: rp.th
                size: 24
                glyph: modelData.g
                label: modelData.l
                on: rp.tab === modelData.k
                onClicked: rp.tab = modelData.k
            }
        }
        Item { Layout.fillWidth: true }
    }

    // ── palette slots ───────────────────────────────────────────
    Flow {
        visible: rp.tab === "palette"
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: Theme.paletteSlots
            Item {
                id: slotItem
                required property string modelData
                width: 34
                height: 40
                Swatch {
                    anchors.horizontalCenter: parent.horizontalCenter
                    th: rp.th
                    width: 26
                    height: 26
                    color: Theme.paletteRef(slotItem.modelData)
                    picked: rp.value === slotItem.modelData
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    text: slotItem.modelData.replace("color", "")
                    color: rp.value === slotItem.modelData ? rp.th.ink : rp.th.faint
                    font { family: rp.th.font; pixelSize: 9 }
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: rp.chosen(slotItem.modelData) }
            }
        }
    }

    // ── other colours of this theme ─────────────────────────────
    Flow {
        visible: rp.tab === "theme"
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            // helpers (aqua, leaf …) first: they're what recipes usually build on
            model: {
                if (!rp.ed) return [];
                const names = rp.ed.colorNames.filter(n => n !== rp.self);
                const known = ["accent", "accent2", "text", "selText", "match", "panelTop", "panelMid", "panelBottom", "panelBorder",
                               "rim", "well", "wellBorder", "field", "fieldBorder", "fieldFocus", "ok", "warn", "crit", "face", "light", "shade", "xp"];
                return names.filter(n => known.indexOf(n) < 0).concat(names.filter(n => known.indexOf(n) >= 0));
            }
            Item {
                id: nameItem
                required property string modelData
                readonly property bool sel: rp.value === "@" + modelData
                width: nameRow.implicitWidth + 16
                height: 26
                Surface {
                    anchors.fill: parent
                    th: rp.th
                    radius: rp.th.pillFull ? height / 2 : rp.th.radiusSm
                    tint: nameItem.sel ? rp.th.accent : rp.th.text
                    strength: nameItem.sel ? 1 : (nameHover.hovered ? 0.35 : 0.14)
                }
                Row {
                    id: nameRow
                    anchors.centerIn: parent
                    spacing: 6
                    Swatch {
                        anchors.verticalCenter: parent.verticalCenter
                        th: rp.th
                        width: 14
                        height: 14
                        radius: 3
                        color: rp.ed ? rp.ed.colorValue(nameItem.modelData) : "transparent"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: nameItem.modelData
                        color: nameItem.sel ? rp.th.selText : rp.th.text
                        font { family: rp.th.font; pixelSize: 11 }
                    }
                }
                HoverHandler { id: nameHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: rp.chosen("@" + nameItem.modelData) }
            }
        }
    }

    // ── one exact colour ────────────────────────────────────────
    ColorPicker {
        visible: rp.tab === "fixed"
        th: rp.th
        Layout.fillWidth: true
        value: rp.kind === "fixed" ? rp.value : (rp.ed ? rp.ed.refValue(rp.value) : "#808080")
        onPicked: (hex) => rp.chosen(hex)
    }
}
