// the wallpaper picker, as a still life: filter chips and a grid of your
// real wallpaper thumbnails (from ~/.cache/wallpicker), the one on screen
// ringed in the accent, the selected one in the second accent
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../common"

Item {
    id: m
    property var th: Theme.t
    property bool animate: true
    property var glass: null                    // the stage's blurred wallpaper (GlassUnder)
    property var thumbs: []                     // file paths (the studio lists a few)
    implicitWidth: 900
    implicitHeight: 600

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
        title: "wallpapers"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            anchors.topMargin: 18 + panel.topInset
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Emblem { th: m.th; glyph: "\u{F0E09}"; size: 38 }
                Text {
                    text: "wallpapers"
                    color: m.th.text
                    font { family: m.th.font; pixelSize: 19; bold: true }
                }
                Item { Layout.fillWidth: true }
                Field {
                    th: m.th
                    implicitWidth: 240
                    implicitHeight: 32
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12
                        text: "\u{F0349}  search"
                        color: m.th.faint
                        font { family: m.th.glyphFont; pixelSize: 13 }
                    }
                }
            }

            RowLayout {
                spacing: 6
                Repeater {
                    model: [ { g: "\u{F02F9}", l: "all 57", on: true }, { g: "\u{F04CE}", l: "favourites 5" }, { g: "\u{F02DA}", l: "recent 8" }, { g: "\u{F024B}", l: "madoka magica 12" } ]
                    Item {
                        id: chip
                        required property var modelData
                        implicitWidth: chipRow.implicitWidth + 18
                        implicitHeight: 26
                        Surface {
                            anchors.fill: parent
                            th: m.th
                            radius: m.th.pillFull ? height / 2 : m.th.radiusSm
                            tint: chip.modelData.on ? m.th.accent : m.th.text
                            strength: chip.modelData.on ? 1 : 0.14
                        }
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: chip.modelData.g; color: chip.modelData.on ? m.th.selText : m.th.dim; font { family: m.th.glyphFont; pixelSize: 13 } }
                            Text { text: chip.modelData.l; color: chip.modelData.on ? m.th.selText : m.th.dim; font { family: m.th.font; pixelSize: 11 } }
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 3
                rowSpacing: 0
                columnSpacing: 0
                Repeater {
                    model: 6
                    Item {
                        id: cell
                        required property int index
                        readonly property bool current: index === 1
                        readonly property bool sel: index === 3
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Item {
                            anchors.fill: parent
                            anchors.margins: 5
                            Surface {
                                anchors.fill: parent
                                th: m.th
                                radius: m.th.radiusSm + 2
                                tint: cell.current ? m.th.accent : cell.sel ? m.th.accent2 : m.th.text
                                strength: cell.current || cell.sel ? 1 : 0.16
                            }
                            ClippingRectangle {
                                anchors.fill: parent
                                anchors.margins: 4
                                radius: Math.max(0, m.th.radiusSm - 2)
                                color: Theme.alpha(m.th.text, 0.05)
                                Image {
                                    anchors.fill: parent
                                    source: m.thumbs[cell.index] ? "file://" + m.thumbs[cell.index] : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                Rectangle {
                                    visible: cell.sel
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                    height: 24
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0) }
                                        GradientStop { position: 0.4; color: Qt.rgba(0, 0, 0, 0.6) }
                                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: 8
                                        text: "selected \u{00B7} 3840\u{00D7}2160"
                                        color: "white"
                                        font { family: m.th.font; pixelSize: 10 }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Keycap { th: m.th; keys: "\u{23CE}"; label: "crop" }
                Keycap { th: m.th; keys: "space"; label: "peek" }
                Keycap { th: m.th; keys: "f"; label: "favourite" }
                Item { Layout.fillWidth: true }
                Keycap { th: m.th; keys: "esc"; label: "close" }
            }
        }
    }
}
