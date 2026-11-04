// one colour of the theme in the inspector: its swatch, name and recipe in
// a line; click to open the recipe editor below it. when the contrast
// solver changed the colour for readability, the final one shows too.
import QtQuick
import QtQuick.Layouts
import "../common"

ColumnLayout {
    id: row
    property var th: Theme.t
    property var ed                              // the studio editor
    property string name
    property string label: name
    property string help: ""
    property bool removable: false               // helper colours can be deleted

    readonly property bool open: ed.openColor === name
    readonly property var raw: ed.colorRaw(name)
    readonly property color value: ed.colorValue(name)
    readonly property var finalValue: ed.tokens ? ed.tokens[name] : undefined
    readonly property bool moved: finalValue !== undefined && String(Qt.color(String(finalValue))) !== String(value)
    spacing: 6
    Layout.fillWidth: true

    Item {
        Layout.fillWidth: true
        implicitHeight: 34

        Surface {
            anchors.fill: parent
            th: row.th
            radius: row.th.radiusSm
            strength: row.open ? 0.5 : (rowHover.hovered ? 0.25 : 0)
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 8
            spacing: 8
            Mark {
                th: row.th
                marked: row.ed.colorOverridden(row.name)
                onCleared: row.ed.clearColor(row.name)
            }
            Swatch { th: row.th; color: row.value }
            Text {
                visible: row.moved
                text: "\u{F0054}"
                color: row.th.faint
                font { family: row.th.glyphFont; pixelSize: 11 }
            }
            Swatch {
                visible: row.moved
                th: row.th
                implicitWidth: 14
                implicitHeight: 14
                radius: 3
                color: row.moved ? row.finalValue : "transparent"
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: row.label
                    elide: Text.ElideRight
                    color: row.th.text
                    font { family: row.th.font; pixelSize: 12 }
                }
                Text {
                    Layout.fillWidth: true
                    text: row.ed.describe(row.raw) + (row.moved ? "  \u{00B7}  contrast-fixed" : "")
                    elide: Text.ElideRight
                    color: row.th.faint
                    font { family: row.th.font; pixelSize: 10 }
                }
            }
            Text {
                visible: row.removable
                text: "\u{F01B4}"
                color: delHover.hovered ? row.th.critInk : row.th.faint
                font { family: row.th.glyphFont; pixelSize: 13 }
                HoverHandler { id: delHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: row.ed.removeColor(row.name) }
            }
            Text {
                text: row.open ? "\u{F0143}" : "\u{F0140}"
                color: row.th.faint
                font { family: row.th.glyphFont; pixelSize: 13 }
            }
        }
        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: row.ed.openColor = row.open ? "" : row.name }
    }

    Text {
        visible: row.open && row.help !== ""
        Layout.fillWidth: true
        Layout.leftMargin: 6
        text: row.help
        wrapMode: Text.WordWrap
        color: row.th.dim
        font { family: row.th.font; pixelSize: 11 }
    }

    Loader {                                     // the editor exists only while open
        active: row.open
        visible: active
        Layout.fillWidth: true
        Layout.leftMargin: 6
        sourceComponent: RecipeEditor {
            th: row.th
            ed: row.ed
            self: row.name
            value: row.raw
            onChanged: (r) => row.ed.setColor(row.name, r)
        }
    }
}
