// a fixed colour: drag in the saturation/value square, pick a hue on the
// strip, or type a hex code. emits "#rrggbb" (opacity is a recipe step)
import QtQuick
import QtQuick.Layouts
import "../common"

Item {
    id: cp
    property var th: Theme.t
    property color value: "#808080"
    signal picked(string hex)

    // hsv kept apart from `value`, so the hue survives greys and blacks
    property real h: 0
    property real s: 0
    property real v: 0.5
    property bool dragging: false

    function sync() {
        const q = Qt.color(String(value));
        if (q.hsvHue >= 0) h = q.hsvHue;
        s = q.hsvSaturation;
        v = q.hsvValue;
    }
    function hexOf(c) {
        const q = Qt.color(String(c));
        const x = n => ("0" + Math.round(n * 255).toString(16)).slice(-2);
        return "#" + x(q.r) + x(q.g) + x(q.b);
    }
    function emit() { picked(hexOf(Qt.hsva(h, s, v, 1))); }
    Component.onCompleted: { sync(); hexBox.text = hexOf(value); }
    onValueChanged: {
        if (!dragging) sync();
        if (!hexBox.input.activeFocus) hexBox.text = hexOf(value);
    }

    implicitWidth: 330
    implicitHeight: 156

    RowLayout {
        anchors.fill: parent
        spacing: 12

        Item {                                               // saturation × value
            id: sv
            Layout.preferredWidth: 156
            Layout.preferredHeight: 156
            Rectangle { anchors.fill: parent; radius: 4; color: Qt.hsva(cp.h, 1, 1, 1) }
            Rectangle {
                anchors.fill: parent
                radius: 4
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#ffffff" }
                    GradientStop { position: 1.0; color: "#00ffffff" }
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: 4
                border.width: 1
                border.color: Theme.alpha(cp.th.text, 0.3)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#00000000" }
                    GradientStop { position: 1.0; color: "#000000" }
                }
            }
            Rectangle {                                      // the marker
                x: cp.s * sv.width - width / 2
                y: (1 - cp.v) * sv.height - height / 2
                width: 12
                height: 12
                radius: 6
                color: "transparent"
                border.width: 2
                border.color: cp.v > 0.55 && cp.s < 0.5 ? "#000000" : "#ffffff"
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                cursorShape: Qt.CrossCursor
                function at(m) {
                    cp.s = Math.max(0, Math.min(1, m.x / width));
                    cp.v = Math.max(0, Math.min(1, 1 - m.y / height));
                    cp.emit();
                }
                onPressed: (m) => { cp.dragging = true; at(m); }
                onPositionChanged: (m) => { if (pressed) at(m); }
                onReleased: cp.dragging = false
            }
        }

        Item {                                               // hue strip
            id: hueStrip
            Layout.preferredWidth: 16
            Layout.preferredHeight: 156
            Rectangle {
                anchors.fill: parent
                radius: 4
                border.width: 1
                border.color: Theme.alpha(cp.th.text, 0.3)
                gradient: Gradient {
                    GradientStop { position: 0.0;   color: Qt.hsva(0.0, 1, 1, 1) }
                    GradientStop { position: 0.167; color: Qt.hsva(0.167, 1, 1, 1) }
                    GradientStop { position: 0.333; color: Qt.hsva(0.333, 1, 1, 1) }
                    GradientStop { position: 0.5;   color: Qt.hsva(0.5, 1, 1, 1) }
                    GradientStop { position: 0.667; color: Qt.hsva(0.667, 1, 1, 1) }
                    GradientStop { position: 0.833; color: Qt.hsva(0.833, 1, 1, 1) }
                    GradientStop { position: 1.0;   color: Qt.hsva(1.0, 1, 1, 1) }
                }
            }
            Rectangle {
                x: -3
                y: cp.h * hueStrip.height - 3
                width: hueStrip.width + 6
                height: 6
                radius: 3
                color: "transparent"
                border.width: 2
                border.color: cp.th.text
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                function at(m) {
                    cp.h = Math.max(0, Math.min(0.999, m.y / height));
                    cp.emit();
                }
                onPressed: (m) => { cp.dragging = true; at(m); }
                onPositionChanged: (m) => { if (pressed) at(m); }
                onReleased: cp.dragging = false
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 8
            Swatch {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                th: cp.th
                color: cp.value
                radius: 6
            }
            TextBox {
                id: hexBox
                th: cp.th
                placeholder: "#rrggbb"
                onEdited: (t) => {
                    const m = /^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{3})$/.exec(t.trim());
                    if (m) cp.picked(cp.hexOf("#" + m[1]));
                    else hexBox.text = cp.hexOf(cp.value);
                }
            }
            Text {
                text: "h " + Math.round(cp.h * 360) + "°  s " + Math.round(cp.s * 100) + "  v " + Math.round(cp.v * 100)
                color: cp.th.faint
                font { family: cp.th.font; pixelSize: 10 }
            }
        }
    }
}
