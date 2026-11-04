// the header badge, per theme:
//   orb     aero: a glass marble with a specular cap
//   glow    neon: the bare glyph, haloed
//   prompt  phosphor: a bracketed glyph on a dark key
//   sun     vaporwave: a striped sunset disc
//   soft    frost: a white tile with the glyph in the accent
//   lens    liquid: a clear glass bead
//   classic classic: a raised bevel button
//   plain   mono: the glyph in a thin rounded square
//   wii     wii: a white button in a wii-blue ring
//   nixie   steins;gate: the glyph glowing inside a glass tube
//   luna    xp: the green start button
//   p5      persona 5: a tilted calling card
import QtQuick
import QtQuick.Effects
import "."

Item {
    id: e
    property var th: Theme.t
    property string glyph
    property color tint: th.accent
    readonly property color ink: String(tint) === String(th.accent) && th.ink ? th.ink : tint
    property real size: 46
    implicitWidth: size
    implicitHeight: size

    Loader {
        anchors.fill: parent
        sourceComponent: {
            switch (e.th.emblem) {
            case "orb":    return orb;
            case "prompt": return prompt;
            case "sun":    return sun;
            case "soft":   return soft;
            case "lens":   return lens;
            case "classic": return classic;
            case "plain":  return plain;
            case "wii":    return wiiE;
            case "nixie":  return nixieE;
            case "luna":   return lunaE;
            case "p5":     return p5E;
            default:       return glow;
            }
        }
    }

    Component {
        id: orb
        Item {
            RectangularShadow {
                anchors.fill: parent
                radius: width / 2
                blur: 14
                color: Theme.alpha(e.tint, 0.55)
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(e.tint, 1.25) }
                    GradientStop { position: 0.5; color: e.tint }
                    GradientStop { position: 1.0; color: Qt.darker(e.tint, 1.9) }
                }
                border.width: 1
                border.color: Qt.darker(e.tint, 2.0)
            }
            Rectangle {
                width: parent.width * 0.62
                height: parent.height * 0.34
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.6
                radius: height / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Theme.alpha(Qt.lighter(e.tint, 2.0), 0.7) }
                }
            }
            Text {
                anchors.centerIn: parent
                text: e.glyph
                color: "white"
                font { family: e.th.glyphFont; pixelSize: Math.round(e.size * 0.42) }
                style: Text.Raised
                styleColor: Theme.alpha(Qt.darker(e.tint, 2.4), 0.8)
            }
            Rectangle {
                width: parent.width * 0.72
                height: parent.height * 0.46
                anchors.horizontalCenter: parent.horizontalCenter
                y: 2
                radius: height / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.68) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.04) }
                }
            }
        }
    }

    Component {
        id: glow
        Item {
            RectangularShadow {
                anchors.centerIn: parent
                width: e.size * 0.5
                height: e.size * 0.5
                radius: width / 2
                blur: 16
                color: Theme.alpha(e.tint, 0.32)
            }
            Text {
                anchors.centerIn: parent
                text: e.glyph
                color: e.ink
                font { family: e.th.glyphFont; pixelSize: Math.round(e.size * 0.44) }
                style: Text.Outline
                styleColor: Theme.alpha(e.tint, 0.28)
            }
        }
    }

    Component {
        id: prompt
        Rectangle {
            radius: e.th.radiusSm
            color: Theme.alpha(e.tint, 0.08)
            border.width: 1
            border.color: Theme.alpha(e.tint, 0.7)
            Text {
                anchors.centerIn: parent
                text: e.glyph
                color: e.ink
                font { family: e.th.glyphFont; pixelSize: Math.round(e.size * 0.40) }
                style: Text.Outline
                styleColor: Theme.alpha(e.tint, 0.3)
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 3
                anchors.top: parent.top
                text: "["
                color: Theme.alpha(e.tint, 0.6)
                font { family: e.th.font; pixelSize: 10 }
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 3
                anchors.bottom: parent.bottom
                text: "]"
                color: Theme.alpha(e.tint, 0.6)
                font { family: e.th.font; pixelSize: 10 }
            }
        }
    }

    Component {
        id: sun
        Item {
            RectangularShadow {
                anchors.fill: parent
                radius: width / 2
                blur: 16
                color: Theme.alpha(e.tint, 0.5)
            }
            Rectangle {
                id: disc
                anchors.fill: parent
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(e.th.warn, 1.1) }
                    GradientStop { position: 1.0; color: e.tint }
                }
            }
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    x: disc.width * 0.12
                    width: disc.width * 0.76
                    height: 1 + index
                    y: disc.height * (0.62 + index * 0.11)
                    color: e.th.panelTop
                }
            }
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -e.size * 0.08
                text: e.glyph
                color: "white"
                font { family: e.th.glyphFont; pixelSize: Math.round(e.size * 0.36) }
                style: Text.Raised
                styleColor: Theme.alpha(Qt.darker(e.tint, 2), 0.7)
            }
        }
    }

    Component {
        id: soft
        Item {
            RectangularShadow {
                anchors.fill: parent
                radius: 14
                blur: 12
                offset: Qt.vector2d(0, 3)
                color: Theme.alpha(e.tint, 0.25)
            }
            Rectangle {
                anchors.fill: parent
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.78)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.95)
            }
            Text {
                anchors.centerIn: parent
                text: e.glyph
                color: e.ink
                font { family: e.th.glyphFont; pixelSize: Math.round(e.size * 0.42) }
            }
        }
    }

    Component {
        id: lens
        Item {
            RectangularShadow {
                anchors.fill: parent
                radius: width / 2
                blur: 14
                offset: Qt.vector2d(0, 3)
                color: Qt.rgba(0, 0, 0, 0.3)
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.22) }
                    GradientStop { position: 1.0; color: Theme.alpha(e.tint, 0.22) }
                }
                border.width: 1.5
                border.color: Qt.rgba(1, 1, 1, 0.65)
            }
            Text {
                anchors.centerIn: parent
                text: e.glyph
                color: "white"
                font { family: e.th.glyphFont; pixelSize: Math.round(e.size * 0.42) }
            }
            Rectangle {
                width: parent.width * 0.6
                height: parent.height * 0.3
                anchors.horizontalCenter: parent.horizontalCenter
                y: 3
                radius: height / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.6) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                }
            }
        }
    }

    Component {
        id: classic
        Item {
            Surface { anchors.fill: parent; th: e.th; strength: 0.4 }
            Text {
                anchors.centerIn: parent
                text: e.glyph
                color: e.ink
                font { family: e.th.glyphFont; pixelSize: Math.round(e.size * 0.46) }
            }
        }
    }

    Component {
        id: plain
        Rectangle {
            radius: e.th.radiusSm
            color: "transparent"
            border.width: 1
            border.color: Theme.alpha(e.th.text, 0.3)
            Text {
                anchors.centerIn: parent
                text: e.glyph
                color: e.th.text
                font { family: e.th.glyphFont; pixelSize: Math.round(e.size * 0.42) }
            }
        }
    }

    Component {
        id: wiiE
        Item {
            RectangularShadow {
                anchors.fill: parent
                radius: width / 2
                blur: 10
                color: Theme.alpha(e.tint, 0.35)
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "#ffffff"
                border.width: 3
                border.color: e.tint
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 5
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: "#d6d6d6"
            }
            Text {
                anchors.centerIn: parent
                text: e.glyph
                color: e.ink
                font { family: e.th.glyphFont; pixelSize: Math.round(e.size * 0.40) }
            }
        }
    }

    Component {
        id: nixieE
        Item {
            Rectangle {                                      // the glass tube
                anchors.horizontalCenter: parent.horizontalCenter
                width: e.size * 0.72
                height: e.size
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.16) }
                    GradientStop { position: 0.5; color: Theme.alpha(e.tint, 0.06) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.4) }
                }
                border.width: 1
                border.color: Theme.alpha(e.tint, 0.35)
                Rectangle {                                  // the mesh
                    anchors.fill: parent
                    anchors.margins: 5
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.alpha(e.tint, 0.12)
                }
            }
            RectangularShadow {
                anchors.centerIn: parent
                width: e.size * 0.4
                height: e.size * 0.5
                radius: width / 2
                blur: 14
                color: Theme.alpha(e.tint, 0.45)
            }
            Text {
                anchors.centerIn: parent
                text: e.glyph
                color: Qt.lighter(e.tint, 1.2)
                font { family: e.th.glyphFont; pixelSize: Math.round(e.size * 0.40) }
                style: Text.Outline
                styleColor: Theme.alpha(e.tint, 0.5)
            }
        }
    }

    Component {
        id: lunaE
        Item {
            Rectangle {
                anchors.fill: parent
                radius: 9
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#5fc35f" }
                    GradientStop { position: 0.45; color: "#3a9b3a" }
                    GradientStop { position: 1.0; color: "#257a25" }
                }
                border.width: 1
                border.color: "#1d5f1d"
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 2 }
                height: parent.height * 0.42
                radius: 7
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.45) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.05) }
                }
            }
            Text {
                anchors.centerIn: parent
                text: e.glyph
                color: "white"
                font { family: e.th.glyphFont; pixelSize: Math.round(e.size * 0.42); italic: true }
                style: Text.Raised
                styleColor: "#1d5f1d"
            }
        }
    }

    Component {
        id: p5E
        Item {
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                rotation: -8
                antialiasing: true
                color: "#000000"
                border.width: 2
                border.color: "#ffffff"
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                rotation: 6
                antialiasing: true
                color: e.tint
            }
            Text {
                anchors.centerIn: parent
                text: e.glyph
                color: "white"
                rotation: -4
                font { family: e.th.glyphFont; pixelSize: Math.round(e.size * 0.42) }
            }
        }
    }
}
