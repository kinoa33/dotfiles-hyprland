// the todo widget, as a still life (layout from TodoWidget/shell.qml)
import QtQuick
import QtQuick.Layouts
import "../common"

Item {
    id: m
    property var th: Theme.t
    property bool animate: true
    property var glass: null                    // the stage's blurred wallpaper (GlassUnder)
    implicitWidth: 420
    implicitHeight: 560

    readonly property var tasks: [
        { t: "finish the theme studio", done: false, hover: true },
        { t: "rice the lock screen", done: false },
        { t: "back up ~/.config", done: true },
        { t: "water the plants", done: false },
        { t: "reply to kana", done: true }
    ]

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
        title: "todo"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            anchors.topMargin: 18 + panel.topInset
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Emblem { th: m.th; glyph: "\u{F0132}"; size: 38 }
                Text {
                    text: "todo"
                    color: m.th.text
                    font { family: m.th.font; pixelSize: 19; bold: true }
                }
                Item { Layout.fillWidth: true }
                Item {
                    implicitWidth: openText.implicitWidth + 18
                    implicitHeight: 22
                    Surface { anchors.fill: parent; th: m.th; radius: m.th.pillFull ? 11 : m.th.radiusSm; strength: 0.45 }
                    Text {
                        id: openText
                        anchors.centerIn: parent
                        text: "3 open"
                        color: m.th.text
                        font { family: m.th.font; pixelSize: 12 }
                    }
                }
            }

            TabBar {
                th: m.th
                current: "tasks"
                model: [ { key: "tasks", label: "tasks", glyph: "\u{F0756}" }, { key: "theme", label: "theme", glyph: "\u{F03D8}" } ]
            }

            Field {
                th: m.th
                Layout.fillWidth: true
                implicitHeight: 40
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 14
                    text: "new task \u{00B7} enter to add"
                    color: m.th.faint
                    font { family: m.th.font; pixelSize: 14 }
                }
            }

            Column {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4
                Repeater {
                    model: m.tasks
                    Item {
                        id: row
                        required property var modelData
                        width: parent.width
                        height: 42
                        Surface { anchors.fill: parent; th: m.th; strength: row.modelData.hover ? 0.35 : 0 }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 10
                            Item {
                                implicitWidth: 20
                                implicitHeight: 20
                                Surface {
                                    anchors.fill: parent
                                    th: m.th
                                    visible: row.modelData.done
                                    radius: m.th.surface === "block" ? 2 : 10
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    visible: !row.modelData.done
                                    radius: m.th.surface === "block" ? 2 : 10
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Theme.alpha(m.th.text, 0.35)
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: row.modelData.done
                                    text: "\u{F012C}"
                                    color: m.th.selText
                                    font { family: m.th.glyphFont; pixelSize: 12 }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.t
                                elide: Text.ElideRight
                                color: row.modelData.done ? m.th.faint : m.th.text
                                font { family: m.th.font; pixelSize: 14; strikeout: row.modelData.done }
                            }
                            Text {
                                visible: !!row.modelData.hover
                                text: "\u{F0156}"
                                color: Theme.alpha(m.th.critInk, 0.75)
                                font { family: m.th.glyphFont; pixelSize: 13 }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text { text: "2 done"; color: m.th.faint; font { family: m.th.font; pixelSize: 12 } }
                Text { text: "clear done"; color: Theme.alpha(m.th.critInk, 0.8); font { family: m.th.font; pixelSize: 12 } }
                Item { Layout.fillWidth: true }
                Keycap { th: m.th; keys: "^tab"; label: "tabs" }
                Keycap { th: m.th; keys: "esc"; label: "close" }
            }
        }
    }
}
