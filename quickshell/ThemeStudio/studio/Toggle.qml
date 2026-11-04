// a labelled on/off switch. `marked` shows a dot when the value is a
// per-widget override (a click on the dot clears it)
import QtQuick
import QtQuick.Layouts
import "../common"

Item {
    id: tg
    property var th: Theme.t
    property string label
    property string note: ""
    property bool on: false
    property bool marked: false
    signal toggled(bool on)
    signal cleared()

    implicitWidth: 180
    implicitHeight: 28

    RowLayout {
        anchors.fill: parent
        spacing: 8

        Mark { marked: tg.marked; th: tg.th; onCleared: tg.cleared() }

        Item {                                               // label + switch: the hit area
            Layout.fillWidth: true
            Layout.fillHeight: true
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: tg.toggled(!tg.on) }

            RowLayout {
                anchors.fill: parent
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: tg.label
                    elide: Text.ElideRight
                    color: tg.th.text
                    font { family: tg.th.font; pixelSize: 12 }
                }
                Text {
                    visible: tg.note !== ""
                    text: tg.note
                    color: tg.th.faint
                    font { family: tg.th.font; pixelSize: 10 }
                }
                Item {
                    implicitWidth: 38
                    implicitHeight: 20
                    Rectangle {                              // the track
                        anchors.fill: parent
                        radius: tg.th.bevel ? 0 : height / 2
                        color: tg.on ? tg.th.fill : Theme.alpha(tg.th.text, 0.12)
                        border.width: 1
                        border.color: tg.on ? Qt.lighter(tg.th.fill, 1.2) : Theme.alpha(tg.th.text, 0.22)
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                    Rectangle {                              // the knob
                        width: 14
                        height: 14
                        radius: tg.th.bevel ? 0 : 7
                        y: 3
                        x: tg.on ? parent.width - width - 3 : 3
                        color: tg.on ? tg.th.selText : Theme.alpha(tg.th.text, 0.7)
                        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                    }
                }
            }
        }
    }
}
