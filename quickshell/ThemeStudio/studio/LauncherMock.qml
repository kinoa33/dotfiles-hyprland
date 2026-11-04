// the launcher, as a still life: search field, mode tabs, favourites and
// a result list with the first row selected — built from the same common
// components the real launcher uses, so the theme looks the same here
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../common"

Item {
    id: m
    property var th: Theme.t
    property bool animate: true
    property var glass: null                    // the stage's blurred wallpaper (GlassUnder)
    implicitWidth: 720
    implicitHeight: 560

    readonly property var rows: [
        { title: "kitty",    sub: "terminal emulator",     icon: "kitty" },
        { title: "Brave",    sub: "web browser",           icon: "brave-browser" },
        { title: "Dolphin",  sub: "file manager",          icon: "org.kde.dolphin" },
        { title: "Obsidian", sub: "notes · knowledge base", icon: "obsidian" },
        { title: "Vesktop",  sub: "discord client",        icon: "vesktop" },
        { title: "GIMP",     sub: "image editor",          icon: "gimp" }
    ]
    // the search letters, lit in the theme's match colour (like the launcher)
    function lit(title, on) {
        const i = title.toLowerCase().indexOf("i");
        if (i < 0) return title;
        const c = on ? String(m.th.selText) : String(m.th.match);
        return title.slice(0, i) + "<font color=\"" + c + "\"><b>" + title.charAt(i) + "</b></font>" + title.slice(i + 1);
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
        title: "launcher"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            anchors.topMargin: 18 + panel.topInset
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Emblem { th: m.th; glyph: "\u{F003B}" }
                Field {
                    th: m.th
                    Layout.fillWidth: true
                    implicitHeight: 46
                    focused: true
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 16
                        spacing: 2
                        Text {
                            text: "i"
                            color: m.th.text
                            font { family: m.th.font; pixelSize: 16 }
                        }
                        Rectangle {                            // the caret
                            width: 2
                            height: 20
                            color: m.th.ink
                        }
                    }
                }
            }

            TabBar {
                th: m.th
                current: "apps"
                model: [
                    { key: "apps",    label: "apps",      glyph: "\u{F003B}" },
                    { key: "windows", label: "windows",   glyph: "\u{F05AF}" },
                    { key: "run",     label: "run",       glyph: "\u{F018D}" },
                    { key: "clip",    label: "clipboard", glyph: "\u{F014C}" },
                    { key: "session", label: "session",   glyph: "\u{F0425}" },
                    { key: "theme",   label: "theme",     glyph: "\u{F03D8}" }
                ]
            }

            RowLayout {                                     // favourites
                Layout.fillWidth: true
                spacing: 14
                Repeater {
                    model: ["kitty", "brave-browser", "org.kde.dolphin", "obsidian", "vesktop"]
                    IconTile {
                        required property string modelData
                        required property int index
                        th: m.th
                        size: 54
                        hot: index === 0
                        icon: Quickshell.iconPath(modelData, true)
                    }
                }
                Item { Layout.fillWidth: true }
            }

            Well {
                th: m.th
                Layout.fillWidth: true
                Layout.fillHeight: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2
                    Repeater {
                        model: m.rows
                        Item {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool sel: index === 0
                            width: parent.width
                            height: 46
                            Surface {
                                anchors.fill: parent
                                th: m.th
                                visible: row.sel
                                tick: true
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 14
                                spacing: 12
                                Image {
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    source: Quickshell.iconPath(row.modelData.icon, true)
                                    sourceSize: Qt.size(60, 60)
                                    smooth: true
                                    mipmap: true
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: m.lit(row.modelData.title, row.sel)
                                        textFormat: Text.StyledText
                                        elide: Text.ElideRight
                                        color: row.sel ? m.th.selText : Theme.alpha(m.th.text, 0.88)
                                        style: row.sel && m.th.raisedText ? Text.Raised : Text.Normal
                                        styleColor: Theme.alpha(Qt.darker(m.th.accent, 2.4), 0.55)
                                        font { family: m.th.font; pixelSize: 14 }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: row.modelData.sub
                                        elide: Text.ElideRight
                                        color: row.sel ? m.th.selDim : m.th.faint
                                        font { family: m.th.font; pixelSize: 11 }
                                    }
                                }
                                Text {
                                    text: row.sel ? "\u{F0142}   \u{23CE}" : ""
                                    color: m.th.selText
                                    font { family: m.th.glyphFont; pixelSize: 13 }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Keycap { th: m.th; keys: "\u{2191}\u{2193}"; label: "move" }
                Keycap { th: m.th; keys: "\u{23CE}"; label: "open" }
                Keycap { th: m.th; keys: "tab"; label: "mode" }
                Item { Layout.fillWidth: true }
                Keycap { th: m.th; keys: "esc"; label: "close" }
            }
        }
    }
}
