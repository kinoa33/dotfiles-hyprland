// a big app tile for favourites, per theme:
// aero bubble · neon hairline square · phosphor bracket box ·
// vaporwave gradient ring · frost white card
import QtQuick
import QtQuick.Effects
import "."

Item {
    id: tile
    property var th: Theme.t
    property string icon                    // image url, may be ""
    property string glyph: "󰣆"
    property bool hot: false
    property real size: 58
    width: size
    height: size

    readonly property bool round: th.surface === "gloss" || th.surface === "gradient" || th.surface === "lens"
    readonly property real r: round ? size / 2 : th.surface === "classic" ? 0
                            : th.surface === "block" ? 3 : th.surface === "soft" ? 18 : 15

    RectangularShadow {
        anchors.fill: parent
        radius: tile.r
        blur: tile.hot ? 20 : 9
        color: Theme.alpha(tile.th.accent, tile.hot ? 0.6 : (tile.th.dark ? 0.24 : 0.18))
        Behavior on blur { NumberAnimation { duration: 200 } }
    }

    // vaporwave: a gradient ring around a dark disc
    Rectangle {
        visible: tile.th.surface === "gradient"
        anchors.fill: parent
        radius: tile.r
        gradient: Gradient {
            GradientStop { position: 0.0; color: tile.th.accent }
            GradientStop { position: 1.0; color: tile.th.accent2 }
        }
    }

    // classic: a raised bevel button
    Surface {
        visible: tile.th.surface === "classic"
        anchors.fill: parent
        th: tile.th
        strength: tile.hot ? 0.4 : 0.36
    }

    Rectangle {
        visible: tile.th.surface !== "classic"
        anchors.fill: parent
        anchors.margins: tile.th.surface === "gradient" ? 2 : 0
        radius: tile.r
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: tile.th.surface === "gloss" || tile.th.surface === "lens" ? Qt.rgba(1, 1, 1, 0.18)
                     : tile.th.surface === "soft" ? Qt.rgba(1, 1, 1, 0.85)
                     : tile.th.surface === "gradient" ? tile.th.panelTop
                     : Theme.alpha(tile.th.text, 0.05)
            }
            GradientStop {
                position: 1.0
                color: tile.th.surface === "gloss" || tile.th.surface === "lens" ? Theme.alpha(Qt.lighter(tile.th.accent, 1.5), 0.38)
                     : tile.th.surface === "soft" ? Qt.rgba(1, 1, 1, 0.6)
                     : tile.th.surface === "gradient" ? tile.th.panelBottom
                     : Theme.alpha(tile.th.accent, 0.08)
            }
        }
        border.width: tile.th.surface === "gradient" ? 0 : 1
        border.color: tile.th.surface === "gloss" || tile.th.surface === "lens" ? Qt.rgba(1, 1, 1, tile.hot ? 0.75 : 0.45)
                    : tile.th.surface === "soft" ? Qt.rgba(1, 1, 1, 1)
                    : Theme.alpha(tile.th.accent, tile.hot ? 0.8 : 0.35)
    }

    Image {
        id: img
        anchors.centerIn: parent
        width: Math.round(tile.size * 0.58)
        height: width
        source: tile.icon
        sourceSize: Qt.size(width * 2, height * 2)
        asynchronous: true
        smooth: true
        mipmap: true
        visible: String(source) !== "" && status === Image.Ready
    }
    Text {
        anchors.centerIn: parent
        visible: !img.visible
        text: tile.glyph
        color: tile.th.dark ? "white" : tile.th.ink
        font { family: tile.th.glyphFont; pixelSize: Math.round(tile.size * 0.42) }
    }

    // aero / liquid: a thin cap of sky across the bubble
    Rectangle {
        visible: tile.th.surface === "gloss" || tile.th.surface === "lens"
        anchors.horizontalCenter: parent.horizontalCenter
        y: 3
        width: parent.width * 0.66
        height: parent.height * 0.26
        radius: height / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.55) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
        }
    }
    // phosphor: corner brackets
    Repeater {
        model: tile.th.surface === "block" ? 4 : 0
        Rectangle {
            required property int index
            width: 7
            height: 7
            color: "transparent"
            border.width: 2
            border.color: tile.th.accent
            x: index % 2 ? tile.width - 5 : -2
            y: index < 2 ? -2 : tile.height - 5
        }
    }
}
