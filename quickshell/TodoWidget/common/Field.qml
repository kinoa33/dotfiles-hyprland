// an input well: recessed glass for aero, hairline for neon,
// underlined slot for phosphor, pill for vaporwave and frost.
// put the TextInput (or anything) inside — it fills the field.
import QtQuick
import "."

Rectangle {
    id: f
    property var th: Theme.t
    property bool focused: false
    default property alias content: slot.data

    radius: th.pillFull ? height / 2 : (th.bevel ? 0 : th.radiusSm + 2)
    color: th.field
    border.width: 1
    border.color: focused ? th.fieldFocus : th.fieldBorder
    Behavior on border.color { ColorAnimation { duration: 200 } }

    // inset: shade under the top lip, light on the bottom lip (aero)
    Rectangle {
        visible: f.th.fieldInset
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
        height: parent.height * 0.45
        radius: f.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.30) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.0) }
        }
    }
    Rectangle {
        visible: f.th.fieldInset || !f.th.dark
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: f.radius; rightMargin: f.radius }
        height: 1
        color: Qt.rgba(1, 1, 1, f.th.dark ? 0.22 : 0.9)
    }
    // phosphor: a glowing underline instead of a lip
    Rectangle {
        visible: f.th.surface === "block"
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
        height: 2
        color: f.focused ? f.th.accent : Theme.alpha(f.th.accent, 0.35)
    }

    // classic: sunken — dark on the top-left, light on the bottom-right
    Item {
        visible: f.th.bevel === true
        anchors.fill: parent
        Rectangle { x: 0; y: 0; width: parent.width; height: 1; color: f.th.shade || "#808080" }
        Rectangle { x: 0; y: 0; width: 1; height: parent.height; color: f.th.shade || "#808080" }
        Rectangle { x: 1; y: 1; width: parent.width - 2; height: 1; color: "#000000" }
        Rectangle { x: 1; y: 1; width: 1; height: parent.height - 2; color: "#000000" }
        Rectangle { x: 0; y: parent.height - 1; width: parent.width; height: 1; color: f.th.light || "#ffffff" }
        Rectangle { x: parent.width - 1; y: 0; width: 1; height: parent.height; color: f.th.light || "#ffffff" }
    }

    Item {
        id: slot
        anchors.fill: parent
    }
}
