// a recessed content area inside a panel: aero gets an inset shadow,
// classic a sunken white list box, glassier themes a faint tint.
import QtQuick
import "."

Rectangle {
    id: w
    property var th: Theme.t

    radius: th.bevel ? 0 : th.radiusSm + 2
    color: th.well
    border.width: th.bevel ? 0 : 1
    border.color: th.wellBorder

    Rectangle {                                          // inset shadow (aero)
        visible: w.th.wellInset
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
        height: 14
        radius: w.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.28) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.0) }
        }
    }
    Item {                                               // sunken bevel (classic)
        visible: w.th.bevel === true
        anchors.fill: parent
        Rectangle { x: 0; y: 0; width: parent.width; height: 1; color: w.th.shade || "#808080" }
        Rectangle { x: 0; y: 0; width: 1; height: parent.height; color: w.th.shade || "#808080" }
        Rectangle { x: 1; y: 1; width: parent.width - 2; height: 1; color: "#000000" }
        Rectangle { x: 1; y: 1; width: 1; height: parent.height - 2; color: "#000000" }
        Rectangle { x: 0; y: parent.height - 1; width: parent.width; height: 1; color: w.th.light || "#ffffff" }
        Rectangle { x: parent.width - 1; y: 0; width: 1; height: parent.height; color: w.th.light || "#ffffff" }
    }
}
