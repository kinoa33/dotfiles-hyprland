// the control center, as a still life (layout from ControlCenter/shell.qml):
// stat bars, the volume and brightness sliders, media, and toggle pills
import QtQuick
import QtQuick.Layouts
import "../common"

Item {
    id: m
    property var th: Theme.t
    property bool animate: true
    property var glass: null                    // the stage's blurred wallpaper (GlassUnder)
    implicitWidth: 420
    implicitHeight: 486

    component Stat: RowLayout {
        property string icon
        property string label
        property real value
        property color accent
        Layout.fillWidth: true
        spacing: 10
        Text { text: icon; color: accent; font.family: m.th.glyphFont; font.pixelSize: 14; Layout.preferredWidth: 20 }
        Text { text: label; color: Theme.alpha(m.th.text, 0.75); font.family: m.th.font; font.pixelSize: 13; Layout.preferredWidth: 42 }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Theme.alpha(m.th.text, 0.08)
            Rectangle {
                width: parent.width * value / 100
                height: parent.height
                radius: 3
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.alpha(accent, 0.55) }
                    GradientStop { position: 1; color: accent }
                }
            }
        }
        Text { text: Math.round(value) + "%"; color: m.th.text; font.family: m.th.font; font.pixelSize: 13; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 44 }
    }

    component Slide: RowLayout {
        property string icon
        property real value
        Layout.fillWidth: true
        spacing: 10
        Text { text: icon; color: m.th.ink; font { family: m.th.glyphFont; pixelSize: 16 } }
        Item {
            Layout.fillWidth: true
            implicitHeight: 24
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 8
                radius: m.th.surface === "block" ? 1 : 4
                color: Theme.alpha(m.th.text, 0.10)
                Rectangle {
                    width: parent.width * value
                    height: parent.height
                    radius: 4
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.alpha(m.th.accent, 0.55) }
                        GradientStop { position: 1; color: m.th.accent }
                    }
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: value * (parent.width - width)
                width: 14; height: 14; radius: m.th.surface === "block" ? 2 : 7
                color: m.th.dark ? m.th.text : "white"
                border.width: 2
                border.color: m.th.accent
            }
        }
        Text { text: Math.round(value * 100) + "%"; color: m.th.text; font.family: m.th.font; font.pixelSize: 12; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight }
    }

    component Pill: Item {
        property string icon
        property string label
        property bool on
        Layout.fillWidth: true
        implicitHeight: 46
        Surface {
            anchors.fill: parent
            th: m.th
            radius: m.th.radiusSm + 2
            tint: on ? m.th.accent : m.th.text
            strength: on ? 1 : 0.2
        }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 1
            Text { Layout.alignment: Qt.AlignHCenter; text: icon; color: on ? m.th.selText : m.th.faint; font { family: m.th.glyphFont; pixelSize: 16 } }
            Text { Layout.alignment: Qt.AlignHCenter; text: label; color: on ? m.th.selText : m.th.faint; font { family: m.th.font; pixelSize: 10 } }
        }
    }

    GlassUnder {
        anchors.fill: parent
        glass: m.glass
        radius: m.th.radius
    }

    ThemedPanel {
        id: panel
        anchors.fill: parent
        th: m.th
        animate: m.animate
        title: "control center"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            anchors.topMargin: 18 + panel.topInset
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Emblem { th: m.th; glyph: "\u{F062E}"; size: 34 }
                ColumnLayout {
                    spacing: 0
                    Text { text: "control center"; color: m.th.text; font { family: m.th.font; pixelSize: 17; bold: true } }
                    Text { text: "up 3h 12m \u{00B7} archlinux"; color: m.th.faint; font { family: m.th.font; pixelSize: 11 } }
                }
                Item { Layout.fillWidth: true }
            }

            TabBar {
                th: m.th
                current: "controls"
                model: [ { key: "controls", label: "controls", glyph: "\u{F062E}" }, { key: "theme", label: "theme", glyph: "\u{F03D8}" } ]
            }

            Well {
                th: m.th
                Layout.fillWidth: true
                implicitHeight: stats.implicitHeight + 24
                ColumnLayout {
                    id: stats
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    Stat { icon: "\u{F0EE0}"; label: "cpu";  value: 23; accent: m.th.accent }
                    Stat { icon: "\u{F035B}"; label: "ram";  value: 61; accent: m.th.accent2 }
                    Stat { icon: "\u{F050F}"; label: "temp"; value: 48; accent: m.th.warnInk }
                    Stat { icon: "\u{F02CA}"; label: "disk"; value: 72; accent: m.th.dim }
                }
            }

            Slide { icon: "\u{F057E}"; value: 0.64 }
            Slide { icon: "\u{F00DF}"; value: 0.8 }

            RowLayout {                                   // media
                Layout.fillWidth: true
                spacing: 12
                Text { text: "\u{F075A}"; color: m.th.ink; font { family: m.th.glyphFont; pixelSize: 18 } }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text { text: "lofi beats \u{2014} chill"; color: m.th.text; font { family: m.th.font; pixelSize: 13 } }
                    Text { text: "spotify"; color: m.th.faint; font { family: m.th.font; pixelSize: 11 } }
                }
                Text { text: "\u{F04AE}  \u{F03E4}  \u{F04AD}"; color: m.th.text; font { family: m.th.glyphFont; pixelSize: 16 } }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: 8
                columnSpacing: 8
                Pill { icon: "\u{F009A}"; label: "dnd"; on: false }
                Pill { icon: "\u{F05A9}"; label: "wifi"; on: true }
                Pill { icon: "\u{F00AF}"; label: "bluetooth"; on: true }
                Pill { icon: "\u{F0176}"; label: "idle lock"; on: false }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
