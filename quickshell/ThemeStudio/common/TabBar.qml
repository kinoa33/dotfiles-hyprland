// pill tabs: model = [{ key, label, glyph }], current = key
import QtQuick
import QtQuick.Layouts
import "."

RowLayout {
    id: bar
    property var th: Theme.t
    property var model: []
    property string current
    signal picked(string key)
    spacing: 6

    Repeater {
        model: bar.model
        delegate: Item {
            id: tab
            required property var modelData
            readonly property bool active: bar.current === modelData.key
            implicitWidth: tabRow.implicitWidth + 26
            implicitHeight: 30

            Surface {
                anchors.fill: parent
                th: bar.th
                radius: bar.th.pillFull ? height / 2 : bar.th.radiusSm
                tint: tab.active ? bar.th.accent : bar.th.text
                strength: tab.active ? 1 : (tabHover.hovered ? 0.3 : 0)
                tick: false
            }
            Row {
                id: tabRow
                anchors.centerIn: parent
                spacing: 7
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                    text: tab.modelData.glyph || ""
                    color: tab.active ? bar.th.selText : bar.th.dim
                    font { family: bar.th.glyphFont; pixelSize: 14 }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.modelData.label
                    color: tab.active ? bar.th.selText : bar.th.dim
                    font { family: bar.th.font; pixelSize: 12 }
                    style: tab.active && bar.th.raisedText ? Text.Raised : Text.Normal
                    styleColor: Theme.alpha(Qt.darker(bar.th.accent, 2.2), 0.7)
                }
            }
            HoverHandler { id: tabHover }
            TapHandler { onTapped: bar.picked(tab.modelData.key) }
        }
    }
}
