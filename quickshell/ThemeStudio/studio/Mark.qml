// the "overridden here" dot in front of a property: shown when the value
// is a per-widget override (or differs from the built-in); a click clears it
import QtQuick
import "../common"

Item {
    id: m
    property var th: Theme.t
    property bool marked: false
    signal cleared()
    implicitWidth: 10
    implicitHeight: 10

    Rectangle {
        anchors.centerIn: parent
        visible: m.marked
        width: hover.hovered ? 9 : 7
        height: width
        radius: width / 2
        color: hover.hovered ? m.th.critInk : m.th.ink
    }
    HoverHandler { id: hover; enabled: m.marked; cursorShape: Qt.PointingHandCursor }
    TapHandler { enabled: m.marked; onTapped: m.cleared() }
}
