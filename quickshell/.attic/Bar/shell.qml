import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

PanelWindow {
    id: root
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 30
    color: "#0f0a00"    
    
    // We only need a tiny exclusive zone for the thin top bar
    WlrLayershell.exclusiveZone: 30

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Repeater {
            model: 9
            Text {
                property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
                property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)

                text: index + 1
                color: isActive ? "#0db9d7" : (ws ? "#7aa2f7" : "#aaaaaa")
                font { pixelSize: 14; bold: true }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("workspace " + (index + 1))
                }
            }
        }

        Item { Layout.fillWidth: true } // Spacer

        Text {
            text: "CPU: " + root.cpuUsage + "%"
            color: "#f2f5fD"
            font { pixelSize: 14; bold: true }
        }

        Rectangle {
            width: 2
            height: 16
            color: "#000000"
        }

        Text {
            text: "Mem: " + root.memUsage + "%"
            color: "#f2f5fD"
            font { pixelSize: 14; bold: true }
        }
    }

    // Hardware Monitoring
    property int cpuUsage: 0
    property var lastCpuIdle: 0
    property var lastCpuTotal: 0
    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split(/\s+/)
                var idle = parseInt(p[4]) + parseInt(p[5])
                var total = p.slice(1, 8).reduce((a, b) => a + parseInt(b), 0)

                if (root.lastCpuTotal !== 0) {
                    var diffIdle = idle - root.lastCpuIdle
                    var diffTotal = total - root.lastCpuTotal
                    if (diffTotal > 0) {
                        root.cpuUsage = Math.round(100 * (1 - diffIdle / diffTotal))
                    }
                }
                root.lastCpuIdle = idle
                root.lastCpuTotal = total
            }
        }
        Component.onCompleted: running = true
    }

    property int memUsage: 0
    Process {
        id: memProc
        command: ["sh", "-c", "free | grep Mem"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split(/\s+/)
                var total = parseInt(parts[1]) || 1
                var used = parseInt(parts[2]) || 0
                root.memUsage = Math.round(100 * used / total)
            }
        }
        Component.onCompleted: running = true
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            cpuProc.running = true
            memProc.running = true
        }
    }
}
