// dunst notifications, as common/ThemeExport.qml dresses them: glass box,
// frame, the accent→accent2 progress bar, a critical one framed in red.
// geometry follows ~/.config/dunst/dunstrc (380 wide, padding 12/14,
// icon up to 48, Pixel Code 11).
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../common"

Item {
    id: m
    property var th: Theme.t
    property bool animate: true
    property var glass: null
    property bool stock: false                  // "rice" untouched: dunst keeps pywal's look
    implicitWidth: 380
    implicitHeight: col.implicitHeight

    readonly property color bg: Theme.alpha(th.dark ? th.panelMid : th.panelTop,
                                            Math.max(0.86, Qt.color(String(th.dark ? th.panelMid : th.panelTop)).a))
    readonly property color frame: th.bevel ? th.shade : th.panelBorder
    readonly property real boxRadius: th.bevel ? 0 : Math.min(18, th.radius)

    component Note: Item {
        id: note
        property string summary
        property string body
        property string icon
        property bool critical: false
        property real progress: -1
        Layout.fillWidth: true
        implicitHeight: noteRow.implicitHeight + 24

        GlassUnder {
            anchors.fill: parent
            glass: m.glass
            radius: m.boxRadius
        }
        Rectangle {
            anchors.fill: parent
            radius: m.boxRadius
            color: note.critical ? Theme.alpha(m.bg, Math.min(1, m.bg.a + 0.06)) : m.bg
            border.width: m.th.bevel || m.th.edge ? 2 : 1
            border.color: note.critical ? m.th.crit : Theme.alpha(m.frame, m.th.bevel ? 1 : 0.9)
        }
        RowLayout {
            id: noteRow
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
            spacing: 12
            Image {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                source: Quickshell.iconPath(note.icon, true)
                sourceSize: Qt.size(88, 88)
                smooth: true
                mipmap: true
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    Layout.fillWidth: true
                    text: note.summary
                    elide: Text.ElideRight
                    color: m.th.text
                    font { family: m.th.font; pixelSize: 14; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: note.body
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: m.th.text
                    font { family: m.th.font; pixelSize: 14 }
                }
                Rectangle {                                 // progress bar
                    visible: note.progress >= 0
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: 8
                    radius: m.th.bevel ? 0 : 4
                    color: Theme.alpha(m.th.text, 0.12)
                    Rectangle {
                        width: parent.width * Math.max(0, note.progress)
                        height: parent.height
                        radius: parent.radius
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: m.th.accent }
                            GradientStop { position: 1.0; color: m.th.accent2 }
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10
        Note { summary: "volume"; body: "speakers \u{00B7} 64%"; icon: "audio-volume-medium"; progress: 0.64 }
        Note { summary: "Vesktop"; body: "kana: did the new rice land yet?"; icon: "vesktop" }
        Note { summary: "battery low"; body: "12% left \u{2014} plug in soon"; icon: "battery-caution"; critical: true }
    }

    Rectangle {
        visible: m.stock
        anchors.fill: parent
        radius: m.boxRadius
        color: Qt.rgba(0, 0, 0, 0.55)
        Text {
            anchors.fill: parent
            anchors.margins: 16
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "rice (untouched): notifications keep dunst's own pywal colours \u{2014} edit the theme to restyle them"
            color: "white"
            font { family: m.th.font; pixelSize: 13 }
        }
    }
}
