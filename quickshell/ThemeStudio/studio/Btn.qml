// a button: an optional glyph, a label and a faint shortcut hint, drawn
// on the theme's own selection surface (so it looks right in every theme)
//   primary  filled with the accent        danger  turns red on hover
//   on       a toggled button, lit like primary
import QtQuick
import "../common"

Item {
    id: b
    property var th: Theme.t
    property string glyph: ""
    property string label: ""
    property string hint: ""
    property bool primary: false
    property bool danger: false
    property bool on: false
    property real size: 30
    signal clicked()

    readonly property bool lit: primary || on || (danger && hover.hovered)
    readonly property color fg: lit ? th.selText : (danger ? th.critInk : th.text)

    implicitWidth: row.implicitWidth + (label !== "" ? 26 : 16)
    implicitHeight: size
    opacity: enabled ? 1 : 0.4

    Surface {
        anchors.fill: parent
        th: b.th
        radius: b.th.pillFull ? height / 2 : b.th.radiusSm
        tint: b.danger ? b.th.crit : (b.primary || b.on ? b.th.accent : b.th.text)
        strength: b.lit ? 1 : (hover.hovered ? 0.4 : 0.18)
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: b.glyph !== ""
            text: b.glyph
            color: b.fg
            font { family: b.th.glyphFont; pixelSize: Math.round(b.size * 0.47) }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: b.label !== ""
            text: b.label
            color: b.fg
            font { family: b.th.font; pixelSize: Math.round(b.size * 0.4) }
            style: b.lit && b.th.raisedText ? Text.Raised : Text.Normal
            styleColor: Theme.alpha(Qt.darker(b.th.accent, 2.2), 0.6)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: b.hint !== ""
            text: b.hint
            color: b.lit ? b.th.selDim : b.th.faint
            font { family: b.th.font; pixelSize: 10 }
        }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: if (b.enabled) b.clicked() }
}
