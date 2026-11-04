// a labelled number slider: drag, scroll, or type a value.
//   hue: true   paints the track as a rainbow (value 0…1 = 0…360°)
//   double-click the label to put the value back to `reset` (if set)
//   shift + scroll nudges the value; a plain scroll scrolls the inspector
import QtQuick
import QtQuick.Layouts
import "../common"

Item {
    id: sl
    property var th: Theme.t
    property string label
    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0.01
    property int decimals: 2
    property string suffix: ""
    property real display: 1                // shown value = value × display (hue: 360)
    property var reset: undefined
    property bool hue: false
    property bool marked: false
    property int labelWidth: 96
    signal moved(real v)
    signal cleared()

    implicitWidth: 260
    implicitHeight: 26

    function snap(v) {
        v = Math.max(from, Math.min(to, v));
        return step > 0 ? Math.round(v / step) * step : v;
    }
    function fmt(v) { return (v * display).toFixed(decimals) + suffix; }
    readonly property real k: to > from ? (Math.max(from, Math.min(to, value)) - from) / (to - from) : 0

    RowLayout {
        anchors.fill: parent
        spacing: 8

        Mark { marked: sl.marked; th: sl.th; onCleared: sl.cleared() }

        Text {
            Layout.preferredWidth: sl.labelWidth
            text: sl.label
            elide: Text.ElideRight
            color: sl.th.dim
            font { family: sl.th.font; pixelSize: 12 }
            TapHandler {
                onDoubleTapped: if (sl.reset !== undefined) sl.moved(sl.reset)
            }
        }

        Item {                                               // the track
            id: track
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: groove
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: sl.hue ? 10 : 6
                radius: sl.th.bevel ? 0 : height / 2
                color: Theme.alpha(sl.th.text, 0.12)
                gradient: sl.hue ? rainbow : null
                border.width: sl.hue ? 1 : 0
                border.color: Theme.alpha(sl.th.text, 0.25)
                Gradient {
                    id: rainbow
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0;   color: Qt.hsla(0.0, 0.85, 0.55, 1) }
                    GradientStop { position: 0.167; color: Qt.hsla(0.167, 0.85, 0.55, 1) }
                    GradientStop { position: 0.333; color: Qt.hsla(0.333, 0.85, 0.55, 1) }
                    GradientStop { position: 0.5;   color: Qt.hsla(0.5, 0.85, 0.55, 1) }
                    GradientStop { position: 0.667; color: Qt.hsla(0.667, 0.85, 0.55, 1) }
                    GradientStop { position: 0.833; color: Qt.hsla(0.833, 0.85, 0.55, 1) }
                    GradientStop { position: 1.0;   color: Qt.hsla(1.0, 0.85, 0.55, 1) }
                }
                Rectangle {                                  // the filled part
                    visible: !sl.hue
                    width: parent.width * sl.k
                    height: parent.height
                    radius: parent.radius
                    color: sl.th.fill
                }
            }
            Rectangle {                                      // the knob
                anchors.verticalCenter: parent.verticalCenter
                x: sl.k * (track.width - width)
                width: 14
                height: 14
                radius: sl.th.bevel ? 0 : 7
                color: sl.hue ? Qt.hsla(sl.value, 0.85, 0.55, 1) : (sl.th.dark ? sl.th.text : "#ffffff")
                border.width: 2
                border.color: sl.hue ? "#ffffff" : sl.th.fill
                scale: drag.pressed ? 1.15 : 1
            }
            MouseArea {
                id: drag
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                function at(mx) { sl.moved(sl.snap(sl.from + Math.max(0, Math.min(1, mx / width)) * (sl.to - sl.from))); }
                onPressed: (m) => at(m.x)
                onPositionChanged: (m) => { if (pressed) at(m.x); }
                onWheel: (w) => {
                    if (!(w.modifiers & Qt.ShiftModifier)) { w.accepted = false; return; }
                    const d = w.angleDelta.y || w.angleDelta.x;      // shift turns some wheels sideways
                    sl.moved(sl.snap(sl.value + (d > 0 ? 1 : -1) * Math.max(sl.step, (sl.to - sl.from) / 50)));
                }
            }
        }

        Item {                                               // the number, typeable
            Layout.preferredWidth: 50
            Layout.fillHeight: true
            TextInput {
                id: num
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignRight
                text: sl.fmt(sl.value)
                color: activeFocus ? sl.th.ink : sl.th.text
                selectionColor: Theme.alpha(sl.th.accent, 0.45)
                selectedTextColor: sl.th.selText
                selectByMouse: true
                font { family: sl.th.font; pixelSize: 12 }
                onEditingFinished: {
                    const v = parseFloat(text);
                    if (!isNaN(v)) sl.moved(sl.snap(v / sl.display));
                    text = Qt.binding(() => sl.fmt(sl.value));
                }
            }
        }
    }
}
