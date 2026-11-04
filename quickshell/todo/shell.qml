import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    property bool open: false

    
    property bool glow: true     
    property bool rtl: false      
    
    property string fontFamily: "Pixel Code"

    // ----------  pywal ----------
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

    // ---------- البيانات ----------
    property var items: []
    property int nextId: 1
    property string filter: "all"
    readonly property int doneCount: items.filter(i => i.done).length

    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.config/quickshell/todo/todos.json"
        onLoaded: {
            try {
                const d = JSON.parse(store.text());
                root.items = d.items || [];
                root.nextId = d.nextId || 1;
            } catch (e) { root.items = []; }
        }
        onLoadFailed: root.items = []
    }

    function save() {
        store.setText(JSON.stringify({ items: root.items, nextId: root.nextId }));
    }
    function add(t) {
        t = t.trim();
        if (!t) return;
        root.items = [{ id: root.nextId, text: t, done: false }].concat(root.items);
        root.nextId++;
        save();
    }
    function toggle(id) {
        root.items = root.items.map(i => i.id === id ? { id: i.id, text: i.text, done: !i.done } : i);
        save();
    }
    function remove(id) {
        root.items = root.items.filter(i => i.id !== id);
        save();
    }
    function clearDone() {
        root.items = root.items.filter(i => !i.done);
        save();
    }

    // qs -c todo ipc call todo toggle
    IpcHandler {
        target: "todo"
        function toggle(): void { root.open = !root.open }
        function open(): void { root.open = true }
        function close(): void { root.open = false }
    }

    
    component GlowText: Text {
        id: gt
        property color glowColor: root.c5
        property real glowOpacity: 0.8
        property bool glowOn: true
        font.family: root.fontFamily
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
        layer.enabled: gt.glowOn && root.glow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: gt.glowColor
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
            implicitWidth: 560
            implicitHeight: 700
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "todo"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

           
            Rectangle {
                id: boxSrc
                anchors.fill: parent
                anchors.margins: 40
                radius: 23
                color: Qt.alpha(root.c0, 0.82)
                border.width: 2
                border.color: Qt.alpha(root.c3, 0.50)
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                source: boxSrc
                anchors.fill: boxSrc
                shadowEnabled: root.glow
                shadowColor: root.c5
                shadowBlur: 1.0
                shadowOpacity: 0.55
                shadowScale: 1.0
            }

            Item {
                id: content
                anchors.fill: boxSrc
                anchors.margins: 18
                LayoutMirroring.enabled: root.rtl
                LayoutMirroring.childrenInherit: true

                /
                Item {
                    id: header
                    width: parent.width
                    height: 42

                    GlowText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "todo"
                        font.pixelSize: 26
                        color: root.c5
                        glowOpacity: 0.95
                    }
                    GlowText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.doneCount + " / " + root.items.length
                        font.pixelSize: 17
                        color: Qt.alpha(root.dim, 0.75)
                        glowColor: root.dim
                        glowOpacity: 0.3
                    }
                }

                
                Rectangle {
                    id: prog
                    anchors.top: header.bottom
                    anchors.topMargin: 4
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Qt.alpha("#ffffff", 0.08)

                    Rectangle {
                        anchors.left: parent.left
                        height: parent.height
                        radius: 3
                        color: root.c5
                        width: root.items.length > 0 ? parent.width * root.doneCount / root.items.length : 0
                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    }
                }

                
                Rectangle {
                    id: inputBox
                    anchors.top: prog.bottom
                    anchors.topMargin: 16
                    width: parent.width
                    height: 50
                    radius: 11
                    color: Qt.alpha(root.c0, 0.35)
                    border.width: 2
                    border.color: input.activeFocus ? Qt.alpha(root.c5, 0.80) : Qt.alpha(root.c3, 0.50)

                    GlowText {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Add a new task..."
                        font.pixelSize: 17
                        color: Qt.alpha(root.fg, 0.45)
                        glowOn: false
                        visible: input.text.length === 0
                    }

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: root.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        color: root.fg
                        selectionColor: root.c5
                        focus: true
                        clip: true

                        function selected() { return list.model.values[list.currentIndex]; }

                        Keys.onEscapePressed: root.open = false
                        Keys.onDownPressed: list.incrementCurrentIndex()
                        Keys.onUpPressed: list.decrementCurrentIndex()
                        Keys.onTabPressed: list.incrementCurrentIndex()
                        Keys.onReturnPressed: (e) => {
                            if (e.modifiers & Qt.ControlModifier) {
                                const s = input.selected();
                                if (s) root.toggle(s.id);
                            } else {
                                root.add(input.text);
                                input.text = "";
                                list.currentIndex = 0;
                            }
                        }
                        Keys.onDeletePressed: {
                            if (input.text.length === 0) {
                                const s = input.selected();
                                if (s) root.remove(s.id);
                            }
                        }
                    }
                }

                
                Item {
                    id: tabRow
                    anchors.top: inputBox.bottom
                    anchors.topMargin: 14
                    width: parent.width
                    height: 36

                    Row {
                        spacing: 8
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: [
                                { k: "all",    l: "All" },
                                { k: "active", l: "Active" },
                                { k: "done",   l: "Done" }
                            ]
                            delegate: Rectangle {
                                id: tab
                                required property var modelData
                                readonly property bool on: root.filter === modelData.k
                                width: tabLabel.implicitWidth + 28
                                height: 32
                                radius: 11
                                color: on ? Qt.alpha(root.c5, 0.14) : Qt.alpha(root.c0, 0.35)
                                border.width: 1
                                border.color: on ? Qt.alpha(root.c5, 0.85)
                                              : (tabHover.containsMouse ? Qt.alpha(root.c5, 0.55) : Qt.alpha(root.c3, 0.25))

                                GlowText {
                                    id: tabLabel
                                    anchors.centerIn: parent
                                    text: tab.modelData.l
                                    font.pixelSize: 15
                                    color: tab.on ? root.c5 : Qt.alpha(root.dim, 0.65)
                                    glowOn: tab.on
                                    glowOpacity: 0.9
                                }
                                MouseArea {
                                    id: tabHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: { root.filter = tab.modelData.k; list.currentIndex = 0; }
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: clearLabel.implicitWidth + 28
                        height: 32
                        radius: 11
                        visible: root.doneCount > 0
                        color: clearHover.containsMouse ? Qt.alpha(root.danger, 0.12) : Qt.alpha(root.c0, 0.35)
                        border.width: 1
                        border.color: clearHover.containsMouse ? Qt.alpha(root.danger, 0.75) : Qt.alpha(root.c3, 0.25)

                        GlowText {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: "Clear done"
                            font.pixelSize: 14
                            color: clearHover.containsMouse ? root.danger : Qt.alpha(root.dim, 0.65)
                            glowColor: root.danger
                            glowOn: clearHover.containsMouse
                            glowOpacity: 0.8
                        }
                        MouseArea {
                            id: clearHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.clearDone()
                        }
                    }
                }

                
                ListView {
                    id: list
                    anchors.top: tabRow.bottom
                    anchors.topMargin: 10
                    anchors.bottom: parent.bottom
                    width: parent.width
                    clip: true
                    spacing: 8
                    currentIndex: 0
                    highlightMoveDuration: 120
                    boundsBehavior: Flickable.StopAtBounds

                    model: ScriptModel {
                        values: root.items.filter(i =>
                            root.filter === "all" ? true
                            : root.filter === "done" ? i.done
                            : !i.done)
                    }

                    GlowText {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: root.items.length === 0 ? "No tasks yet" : "Nothing here"
                        font.pixelSize: 18
                        color: Qt.alpha(root.dim, 0.45)
                        glowOn: false
                    }

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool sel: ListView.isCurrentItem
                        readonly property bool done: modelData.done

                        width: list.width
                        height: Math.max(54, label.implicitHeight + 28)

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: 11
                            color: row.sel ? Qt.alpha(root.c5, 0.12) : Qt.alpha(root.c0, 0.35)
                            border.width: 1
                            border.color: row.sel ? Qt.alpha(root.c5, 0.85)
                                          : (hover.containsMouse ? Qt.alpha(root.c5, 0.55) : Qt.alpha(root.c3, 0.25))
                        }

                        
                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: list.currentIndex = row.index
                            onClicked: root.toggle(row.modelData.id)
                        }

                        
                        Rectangle {
                            id: cb
                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24
                            radius: 8
                            color: row.done ? Qt.alpha(root.c5, 0.25) : "transparent"
                            border.width: 2
                            border.color: row.done ? root.c5 : Qt.alpha(root.dim, 0.5)

                            Rectangle {
                                anchors.centerIn: parent
                                width: 12
                                height: 12
                                radius: 4
                                color: root.c5
                                visible: row.done
                            }
                        }

                        GlowText {
                            id: label
                            anchors.left: cb.right
                            anchors.leftMargin: 14
                            anchors.right: del.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.text
                            wrapMode: Text.Wrap
                            font.pixelSize: 17
                            font.strikeout: row.done
                            color: row.done ? Qt.alpha(root.dim, 0.40)
                                   : (row.sel ? root.c5 : Qt.alpha(root.fg, 0.88))
                            glowOn: row.sel && !row.done
                            glowOpacity: 0.9
                        }

                        // زر الحذف
                        Item {
                            id: del
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30

                            GlowText {
                                anchors.centerIn: parent
                                text: "×"
                                font.pixelSize: 24
                                color: delHover.containsMouse ? root.danger : Qt.alpha(root.dim, 0.45)
                                glowColor: root.danger
                                glowOn: delHover.containsMouse
                                glowOpacity: 0.9
                            }
                            MouseArea {
                                id: delHover
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.remove(row.modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
