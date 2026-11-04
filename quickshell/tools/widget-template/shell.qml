// ╔══════════════════════════════════════════════════════════════╗
// ║  __LABEL__ · a themed overlay (quickshell)                   ║
// ║  toggle: hypr/scripts/qs-toggle.sh __NAME__                  ║
// ║  tabs: main · theme (ctrl+tab / alt+1,2)                     ║
// ║  made from tools/widget-template — see ../README.md          ║
// ╚══════════════════════════════════════════════════════════════╝
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "common"

PanelWindow {
    id: root

    readonly property var th: Theme.t                 // this widget's tokens (Theme.widget below)
    readonly property int margin: 44                  // room for the shadow and the pop-in
    property string tab: "main"

    // sized to the panel, not the screen: hyprland only re-blurs this
    // patch when the glass animates. a click anywhere else closes it.
    implicitWidth: panel.width + margin * 2
    implicitHeight: panel.height + margin * 2
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-__KEY__"     // add it to the blur layerrule (hypr/conf/windowrules.conf)
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: Qt.quit()
    }

    Component.onCompleted: Theme.widget = "__KEY__"   // must match a key in Theme.widgets

    function setTab(t) {
        root.tab = t;
        if (t === "theme") picker.forceActiveFocus();
    }

    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+Tab"; context: Qt.ApplicationShortcut; onActivated: root.setTab(root.tab === "main" ? "theme" : "main") }
    Shortcut { sequence: "Alt+1"; context: Qt.ApplicationShortcut; onActivated: root.setTab("main") }
    Shortcut { sequence: "Alt+2"; context: Qt.ApplicationShortcut; onActivated: root.setTab("theme") }

    MouseArea { anchors.fill: parent; onClicked: Qt.quit() }      // the transparent margin

    ThemedPanel {
        id: panel
        title: "__LABEL__"                            // shown by the classic / luna title bar
        x: root.margin
        y: root.margin
        width: 420
        height: 520

        opacity: 0                                    // pop in
        scale: 0.96
        Component.onCompleted: { opacity = 1; scale = 1; }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
        Behavior on scale   { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

        MouseArea { anchors.fill: parent }           // clicks on the panel don't close it

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            anchors.topMargin: 18 + panel.topInset
            spacing: 12

            RowLayout {                                // header
                Layout.fillWidth: true
                spacing: 10
                Emblem { glyph: root.tab === "theme" ? "\u{F03D8}" : "\u{F0219}"; size: 38 }
                Text {
                    text: root.tab === "theme" ? "theme" : "__LABEL__"
                    color: root.th.text
                    font { family: root.th.font; pixelSize: 19; bold: true }
                }
                Item { Layout.fillWidth: true }
            }

            TabBar {
                model: [
                    { key: "main",  label: "__LABEL__", glyph: "\u{F0219}" },
                    { key: "theme", label: "theme",     glyph: "\u{F03D8}" }
                ]
                current: root.tab
                onPicked: (key) => root.setTab(key)
            }

            Well {                                     // ── your content goes here ──
                visible: root.tab === "main"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Text {
                    anchors.centerIn: parent
                    text: "hello from __NAME__"
                    color: root.th.dim
                    font { family: root.th.font; pixelSize: 14 }
                }
            }

            ThemePicker {                              // the theme tab (studio: E)
                id: picker
                visible: root.tab === "theme"
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            RowLayout {                                // footer key hints
                Layout.fillWidth: true
                spacing: 12
                Keycap { visible: root.tab === "theme"; keys: "\u{23CE}"; label: "apply" }
                Keycap { visible: root.tab === "theme"; keys: "E"; label: "studio" }
                Item { Layout.fillWidth: true }
                Keycap { keys: "^tab"; label: "tabs" }
                Keycap { keys: "esc"; label: "close" }
            }
        }
    }
}
