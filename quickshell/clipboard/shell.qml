import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    property bool open: false

    FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter {
            id: wal
            property JsonObject colors: JsonObject {
                property string color0: "#1e1e2e"
                property string color3: "#94e2d5"
                property string color5: "#cba6f7"
            }
        }
    }
    readonly property color c0: wal.colors.color0
    readonly property color c3: wal.colors.color3
    readonly property color c5: wal.colors.color5
    readonly property color fg: "#E7E6ED"
    readonly property color dim: "#D8D8D8"
    readonly property color danger: "#e64553"

    // qs -c clipboard ipc call clipboard toggle
    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.open = !root.open }
        function open(): void { root.open = true }
        function close(): void { root.open = false }
    }

    function pick(id) {
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", id]);
        root.open = false;
    }

    component GlowText: Text {
        id: gt
        property color glow: root.c5
        property real glowOpacity: 0.8
        font.family: "Pixel Code"
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: gt.glow
            shadowBlur: 0.9
            shadowOpacity: gt.glowOpacity
            shadowVerticalOffset: 0
            shadowHorizontalOffset: 0
        }
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            id: win
            implicitWidth: 540
            implicitHeight: 660
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "clipboard"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            
            property var all: []

            Process {
                id: lister
                command: ["cliphist", "list"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        const out = [];
                        for (const line of this.text.split("\n")) {
                            if (!line) continue;
                            const t = line.indexOf("\t");
                            if (t < 0) continue;
                            out.push({
                                id: line.substring(0, t),
                                line: line,
                                text: line.substring(t + 1).replace(/\s+/g, " ").trim()
                            });
                        }
                        win.all = out;
                    }
                }
            }

            Rectangle {
                id: boxSrc
                anchors.fill: parent
                anchors.margins: 40
                radius: 23
                color: Qt.alpha(root.c0, 0.70)
                border.width: 2
                border.color: Qt.alpha(root.c3, 0.50)
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                source: boxSrc
                anchors.fill: boxSrc
                shadowEnabled: true
                shadowColor: root.c5
                shadowBlur: 1.0
                shadowOpacity: 0.55
                shadowScale: 1.0
            }

            Item {
                anchors.fill: boxSrc
                anchors.margins: 14

               
                Rectangle {
                    id: searchBox
                    width: parent.width
                    height: 46
                    radius: 11
                    color: Qt.alpha(root.c0, 0.35)
                    border.width: 2
                    border.color: input.activeFocus ? Qt.alpha(root.c5, 0.80) : Qt.alpha(root.c3, 0.50)

                    GlowText {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Clipboard..."
                        font.pixelSize: 16
                        font.italic: true
                        color: Qt.alpha(root.fg, 0.45)
                        visible: input.text.length === 0
                    }

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: "Pixel Code"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: root.fg
                        selectionColor: root.c5
                        focus: true
                        clip: true

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: root.c5
                            shadowBlur: 0.8
                            shadowOpacity: 0.6
                        }

                        onTextChanged: list.currentIndex = 0

                        Keys.onEscapePressed: root.open = false
                        Keys.onDownPressed: list.incrementCurrentIndex()
                        Keys.onUpPressed: list.decrementCurrentIndex()
                        Keys.onTabPressed: list.incrementCurrentIndex()
                        Keys.onReturnPressed: {
                            const e = list.model.values[list.currentIndex];
                            if (e) root.pick(e.id);
                        }
                        
                        Keys.onDeletePressed: {
                            const e = list.model.values[list.currentIndex];
                            if (!e) return;
                            Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", e.line]);
                            win.all = win.all.filter(x => x.id !== e.id);
                        }
                    }
                }

                
                ListView {
                    id: list
                    anchors.top: searchBox.bottom
                    anchors.topMargin: 12
                    anchors.bottom: parent.bottom
                    width: parent.width
                    clip: true
                    spacing: 8
                    currentIndex: 0
                    highlightMoveDuration: 120
                    boundsBehavior: Flickable.StopAtBounds

                    model: ScriptModel {
                        values: {
                            const q = input.text.toLowerCase();
                            return win.all.filter(e => e.text.toLowerCase().includes(q)).slice(0, 100);
                        }
                    }

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool sel: ListView.isCurrentItem
                        readonly property bool isBinary: modelData.text.startsWith("[[ binary data")

                        width: list.width
                        height: 52

                        Rectangle {
                            id: bgSrc
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: 11
                            color: row.sel ? Qt.alpha(root.c5, 0.12) : Qt.alpha(root.c0, 0.35)
                            border.width: 1
                            border.color: row.sel ? Qt.alpha(root.c5, 0.85)
                                          : (hover.containsMouse ? Qt.alpha(root.c5, 0.60) : Qt.alpha(root.c3, 0.25))
                            visible: false
                            layer.enabled: true
                        }
                        MultiEffect {
                            source: bgSrc
                            anchors.fill: bgSrc
                            shadowEnabled: row.sel || hover.containsMouse
                            shadowColor: root.c5
                            shadowBlur: 0.9
                            shadowOpacity: row.sel ? 0.55 : 0.25
                        }

                        GlowText {
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.right: parent.right
                            anchors.rightMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.text
                            elide: Text.ElideRight
                            font.pixelSize: 16
                            font.italic: row.isBinary
                            color: (row.sel || hover.containsMouse) ? root.c5 : Qt.alpha(root.dim, 0.60)
                            glow: (row.sel || hover.containsMouse) ? root.c5 : root.dim
                            glowOpacity: row.sel ? 0.95 : (hover.containsMouse ? 0.7 : 0.25)
                        }

                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: list.currentIndex = row.index
                            onClicked: root.pick(row.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
