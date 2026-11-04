// a collapsible group in the inspector: a header you click, the rows below
import QtQuick
import QtQuick.Layouts
import "../common"

ColumnLayout {
    id: sec
    property var th: Theme.t
    property string title
    property string glyph: ""
    property string note: ""
    property bool open: true
    default property alias content: body.data
    spacing: 6
    Layout.fillWidth: true

    Item {
        Layout.fillWidth: true
        implicitHeight: 30
        RowLayout {
            anchors.fill: parent
            spacing: 8
            Text {
                text: sec.open ? "󰅀" : "󰅂"
                color: sec.th.faint
                font { family: sec.th.glyphFont; pixelSize: 13 }
            }
            Text {
                visible: sec.glyph !== ""
                text: sec.glyph
                color: sec.th.ink
                font { family: sec.th.glyphFont; pixelSize: 15 }
            }
            Text {
                text: sec.title
                color: sec.th.text
                font { family: sec.th.font; pixelSize: 13; bold: true }
            }
            Text {
                Layout.fillWidth: true
                text: sec.note
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                color: sec.th.faint
                font { family: sec.th.font; pixelSize: 10 }
            }
        }
        Rectangle {                                          // hairline under the header
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.alpha(sec.th.text, 0.1)
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: sec.open = !sec.open }
    }

    ColumnLayout {
        id: body
        visible: sec.open
        Layout.fillWidth: true
        Layout.leftMargin: 4
        spacing: 6
    }
}
