// the screenshot tool (HyprQuickFrame, Alt+S), as common/ThemeExport.qml
// dresses it: the dimmed screen, a region outlined in the accent, and the
// segmented bar — Edit, Region (lit), Window, Temp
import QtQuick
import "../common"

Item {
    id: m
    property var th: Theme.t
    property bool animate: true
    property var glass: null
    implicitWidth: 960
    implicitHeight: 600

    readonly property real dim: th.dark ? 0.6 : 0.45
    readonly property rect sel: Qt.rect(250, 120, 460, 270)
    readonly property real rad: th.bevel ? 0 : Math.min(14, th.radiusSm)
    // the lit segment is solid: black or white text, whichever reads (as exported)
    readonly property color onFill: Theme.contrast("#ffffff", th.fill) >= Theme.contrast("#111318", th.fill) ? "#ffffff" : "#111318"

    // the dim layer, cut around the selection
    Rectangle { x: 0; y: 0; width: m.width; height: m.sel.y; color: Qt.rgba(0, 0, 0, m.dim) }
    Rectangle { x: 0; y: m.sel.y + m.sel.height; width: m.width; height: m.height - y; color: Qt.rgba(0, 0, 0, m.dim) }
    Rectangle { x: 0; y: m.sel.y; width: m.sel.x; height: m.sel.height; color: Qt.rgba(0, 0, 0, m.dim) }
    Rectangle { x: m.sel.x + m.sel.width; y: m.sel.y; width: m.width - x; height: m.sel.height; color: Qt.rgba(0, 0, 0, m.dim) }
    Rectangle {                                         // the selection outline
        x: m.sel.x; y: m.sel.y; width: m.sel.width; height: m.sel.height
        radius: m.rad
        color: "transparent"
        border.width: 2
        border.color: m.th.fill
    }
    Text {
        x: m.sel.x + 8; y: m.sel.y + m.sel.height + 8
        text: m.sel.width + " \u{00D7} " + m.sel.height
        color: "white"
        font { family: m.th.font; pixelSize: 12 }
    }

    // the control bar
    Item {
        id: bar
        readonly property var modes: [ { k: "edit", g: "\u{F03EB}", l: "Edit" }, { k: "region", g: "\u{F0489}", l: "Region" },
                                       { k: "window", g: "\u{F10AC}", l: "Window" }, { k: "temp", g: "\u{F0147}", l: "Temp" } ]
        width: modes.length * 100 + 8
        height: 50
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        GlassUnder { anchors.fill: parent; glass: m.glass; radius: height / 2 }
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.alpha(m.th.dark ? m.th.panelMid : m.th.panelTop,
                               Math.max(0.55, Qt.color(String(m.th.dark ? m.th.panelMid : m.th.panelTop)).a))
            border.width: 1
            border.color: m.th.panelBorder
        }
        Rectangle {                                     // the lit segment (region)
            x: 104; y: 4
            width: 100
            height: parent.height - 8
            radius: height / 2
            color: m.th.fill
        }
        Row {
            anchors.fill: parent
            anchors.margins: 4
            Repeater {
                model: bar.modes
                Item {
                    required property var modelData
                    required property int index
                    width: 100
                    height: bar.height - 8
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.g + "  " + parent.modelData.l
                        color: parent.index === 1 ? m.onFill : Theme.alpha(m.th.text, 0.8)
                        font { family: m.th.glyphFont; pixelSize: 15; bold: parent.index === 1 }
                    }
                }
            }
        }
    }
}
