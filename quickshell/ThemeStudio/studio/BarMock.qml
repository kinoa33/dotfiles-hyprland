// waybar, as common/ThemeExport.qml dresses it: the glass strip, the
// workspace well with the active pill, the window title, the modules on
// the right in their status colours. waybar itself is gtk css — this is a
// faithful qml stand-in, so you can judge a theme on the bar before saving.
import QtQuick
import QtQuick.Layouts
import "../common"

Item {
    id: m
    property var th: Theme.t
    property bool animate: true
    property var glass: null
    property bool stock: false                  // "rice" untouched: waybar keeps base.css
    implicitWidth: 1240
    implicitHeight: 37

    readonly property real barRadius: Math.min(18, th.radius)
    readonly property real wellRadius: th.bevel ? 0 : Math.min(13, th.radiusSm + 3)
    readonly property real modRadius: th.bevel ? 0 : Math.min(11, th.radiusSm)
    readonly property color well: String(th.well) === "#00000000" || th.well === "transparent" ? Theme.alpha(th.text, 0.06) : th.well

    component Mod: Item {
        id: mod
        property string text
        property color color: m.th.text
        property bool glyph: false
        property bool bold: false
        property bool italic: false
        property real hover: 0                  // a hover state, drawn like waybar's :hover
        implicitWidth: label.implicitWidth + 20
        implicitHeight: 29
        Surface {
            anchors.fill: parent
            th: m.th
            radius: m.modRadius
            strength: mod.hover
        }
        Text {
            id: label
            anchors.centerIn: parent
            text: mod.text
            color: mod.color
            style: m.th.glow ? Text.Outline : (m.th.raisedText ? Text.Raised : Text.Normal)
            styleColor: m.th.glow ? Theme.alpha(m.th.accent, 0.35) : Qt.rgba(0, 0, 0, 0.45)
            font { family: mod.glyph ? m.th.glyphFont : m.th.font; pixelSize: mod.glyph ? 16 : 15; bold: mod.bold; italic: mod.italic }
        }
    }

    GlassUnder {
        anchors.fill: parent
        glass: m.glass
        radius: m.barRadius
    }

    Rectangle {                                         // window#waybar
        anchors.fill: parent
        radius: m.barRadius
        gradient: Gradient {
            GradientStop { position: 0.0; color: m.th.panelTop }
            GradientStop { position: 0.4; color: m.th.panelMid }
            GradientStop { position: 1.0; color: m.th.panelBottom }
        }
        border.width: m.th.bevel ? 0 : 1
        border.color: m.th.panelBorder
        Rectangle {                                     // sheen
            visible: m.th.sheen
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, parent.radius - 1)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, m.th.dark ? 0.16 : 0.42) }
                GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.03) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
        Item {                                          // classic: a raised frame
            visible: m.th.bevel === true
            anchors.fill: parent
            Rectangle { x: 0; y: 0; width: parent.width; height: 1; color: m.th.light || "#ffffff" }
            Rectangle { x: 0; y: 0; width: 1; height: parent.height; color: m.th.light || "#ffffff" }
            Rectangle { x: 0; y: parent.height - 1; width: parent.width; height: 1; color: "#000000" }
            Rectangle { x: parent.width - 1; y: 0; width: 1; height: parent.height; color: "#000000" }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 1

        Mod { text: "\u{F08C7}"; glyph: true; color: m.th.ink }            // arch
        Item {                                          // workspaces
            implicitWidth: wsRow.implicitWidth + 10
            implicitHeight: 27
            Rectangle {
                anchors.fill: parent
                radius: m.wellRadius
                color: m.well
            }
            Row {
                id: wsRow
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: [ { n: "1", s: "busy" }, { n: "2", s: "active" }, { n: "3", s: "busy" }, { n: "4", s: "empty" }, { n: "5", s: "empty" } ]
                    Item {
                        id: ws
                        required property var modelData
                        readonly property bool active: modelData.s === "active"
                        width: wsText.implicitWidth + (active ? 26 : 10)
                        height: 23
                        Surface {
                            anchors.fill: parent
                            th: m.th
                            visible: ws.active
                            radius: m.th.bevel ? 0 : 11
                        }
                        Text {
                            id: wsText
                            anchors.centerIn: parent
                            text: "\u{F0AE2}"                    // the bar's sparkle, lit by state
                            color: ws.active ? m.th.selText : Theme.alpha(m.th.text, ws.modelData.s === "empty" ? 0.24 : 0.42)
                            font { family: m.th.glyphFont; pixelSize: 14 }
                        }
                    }
                }
            }
        }
        Mod { text: "\u{F075A}  lofi beats \u{2014} chill"; color: m.th.dark ? m.th.accent2 : m.th.ink }

        Item { Layout.fillWidth: true }
        Item {                                          // the focused window's title
            implicitWidth: title.implicitWidth + 36
            implicitHeight: 29
            Rectangle { anchors.fill: parent; radius: m.th.bevel ? 0 : 11; color: m.well }
            Text {
                id: title
                anchors.centerIn: parent
                text: "kitty \u{2014} ~/.config/quickshell"
                color: Theme.alpha(m.th.text, 0.88)
                font { family: m.th.font; pixelSize: 15; italic: true }
            }
        }
        Item { Layout.fillWidth: true }

        Mod { text: "\u{F0176}"; glyph: true; color: m.th.dark ? m.th.warnInk : m.th.ink }   // idle on
        Mod { text: "\u{F009A}"; glyph: true; color: Theme.alpha(m.th.text, 0.78) }          // dnd
        Mod { text: "\u{F05A9}  home"; color: m.th.text; hover: 0.45 }                        // network (hovered)
        Mod { text: "\u{F030C}  us"; color: m.th.dim }
        Mod { text: "\u{F0080} 86%"; color: m.th.okInk }
        Mod { text: "21:47"; color: m.th.text; bold: true }
        Mod { text: "\u{F03D8}"; glyph: true; color: m.th.ink }                              // theme
        Mod { text: "\u{F0425}"; glyph: true; color: Theme.alpha(m.th.crit, 0.9) }           // power
    }

    Rectangle {                                         // "rice" keeps base.css
        visible: m.stock
        anchors.fill: parent
        radius: m.barRadius
        color: Qt.rgba(0, 0, 0, 0.55)
        Text {
            anchors.centerIn: parent
            text: "rice (untouched): waybar wears your own waybar/base.css \u{2014} edit the theme to restyle the bar"
            color: "white"
            font { family: m.th.font; pixelSize: 13 }
        }
    }
}
