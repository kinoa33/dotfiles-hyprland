// a selected / active / pressed surface, drawn the way the theme draws it
//   gloss     aero: tinted body, hard gloss line, light pooling, white rim
//   flat      neon: faint tint, hairline border, optional accent tick
//   block     phosphor: a solid inverted block
//   gradient  vaporwave: accent → accent2 sweep with a bright top edge
//   soft      frost/sakura: a gentle tinted pill with a white lip
//   ricepill  rice: the bar's workspace pill — accent → soft fade
//   lens      liquid: clear glass with bright specular edges
//   classic   classic: solid when selected, a raised bevel button otherwise
//   wii       wii: a white capsule with a glowing wii-blue ring
//   nixie     steins;gate: dark glass, an amber filament glow
//   xmb       ps3: a soft white glow bar, no box at all
//   p5        persona 5: a tilted red card on a black shadow
//   chrome    y2k: brushed metal with an iridescent wash
// strength 0…1 fades the whole thing (0 = invisible, for hover states)
import QtQuick
import QtQuick.Effects
import "."

Item {
    id: s
    property var th: Theme.t
    property color tint: th.accent
    // the plain accent selects with its contrast-solved twin (Theme.readable)
    readonly property color body: String(tint) === String(th.accent) && th.fill ? th.fill
                                : String(tint) === String(th.crit) && th.critFill ? th.critFill : tint
    property real strength: 1
    property real radius: th.radiusSm
    property bool tick: false

    visible: strength > 0.001

    Loader {
        anchors.fill: parent
        sourceComponent: {
            switch (s.th.surface) {
            case "gloss":    return gloss;
            case "block":    return block;
            case "gradient": return gradient;
            case "soft":     return soft;
            case "ricepill": return ricepill;
            case "lens":     return lens;
            case "classic":  return classic;
            case "wii":      return wii;
            case "nixie":    return nixie;
            case "xmb":      return xmb;
            case "p5":       return p5;
            case "chrome":   return chrome;
            default:         return flat;
            }
        }
    }

    Component {
        id: gloss
        Item {
            Rectangle {
                anchors.fill: parent
                radius: s.radius
                // light themes sit on a bright well: near-opaque, or white text washes out
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.alpha(Qt.lighter(s.body, 1.25), (s.th.dark ? 0.80 : 0.95) * s.strength) }
                    GradientStop { position: 0.5; color: Theme.alpha(s.body, (s.th.dark ? 0.62 : 0.90) * s.strength) }
                    GradientStop { position: 1.0; color: Theme.alpha(Qt.darker(s.body, 1.25), (s.th.dark ? 0.74 : 0.93) * s.strength) }
                }
                border.width: 1
                border.color: Theme.alpha(Qt.lighter(s.body, 1.15), Math.min(1, 0.95 * s.strength))
            }
            Rectangle {
                x: 1
                y: 1
                width: parent.width - 2
                height: Math.round((parent.height - 2) * 0.48)
                radius: Math.max(0, s.radius - 1)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.38 * s.strength) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.10 * s.strength) }
                }
            }
            Rectangle {
                x: parent.width * 0.1
                width: parent.width * 0.8
                height: parent.height * 0.34
                y: parent.height - height - 1
                radius: height / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Theme.alpha(Qt.lighter(s.body, 1.7), 0.30 * s.strength) }
                }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, s.radius - 1)
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.22 * s.strength)
            }
        }
    }

    Component {
        id: flat
        Item {
            Rectangle {
                anchors.fill: parent
                radius: s.radius
                color: Theme.alpha(s.body, 0.15 * s.strength)
                border.width: 1
                border.color: Theme.alpha(s.body, 0.38 * s.strength)
            }
            Rectangle {
                visible: s.tick
                anchors.left: parent.left
                anchors.leftMargin: 3
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: Math.min(20, parent.height - 8)
                radius: 2
                color: Theme.alpha(s.body, s.strength)
            }
        }
    }

    Component {
        id: block
        Rectangle {
            radius: s.radius
            color: Theme.alpha(s.body, (s.strength >= 0.99 ? 0.92 : 0.22) * s.strength)
            border.width: s.strength >= 0.99 ? 0 : 1
            border.color: Theme.alpha(s.body, 0.5 * s.strength)
        }
    }

    Component {
        id: gradient
        Item {
            Rectangle {
                anchors.fill: parent
                radius: s.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.alpha(s.body, 0.70 * s.strength) }
                    GradientStop { position: 1.0; color: Theme.alpha(s.th.accent2, 0.55 * s.strength) }
                }
                border.width: 1
                border.color: Theme.alpha(Qt.lighter(s.body, 1.3), 0.7 * s.strength)
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: s.radius; rightMargin: s.radius; topMargin: 1 }
                height: 1
                color: Qt.rgba(1, 1, 1, 0.45 * s.strength)
            }
        }
    }

    Component {
        id: soft
        Item {
            Rectangle {
                anchors.fill: parent
                radius: s.radius
                color: Theme.alpha(s.body, 0.17 * s.strength)
                border.width: 1
                border.color: Theme.alpha(s.body, 0.42 * s.strength)
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: s.radius / 2; rightMargin: s.radius / 2; topMargin: 1 }
                height: 1
                color: Qt.rgba(1, 1, 1, 0.7 * s.strength)
            }
        }
    }

    Component {
        id: ricepill
        Rectangle {
            radius: s.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.alpha(s.body, 0.30 * s.strength) }
                GradientStop { position: 1.0; color: Theme.alpha(s.th.accent2, 0.10 * s.strength) }
            }
            border.width: 1
            border.color: Theme.alpha(s.body, 0.20 * s.strength)
        }
    }

    Component {
        id: lens
        Item {
            Rectangle {
                anchors.fill: parent
                radius: s.radius
                // tinted glass: a lens you can read white text through
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.16 * s.strength) }
                    GradientStop { position: 0.35; color: Theme.alpha(s.body, 0.34 * s.strength) }
                    GradientStop { position: 1.0; color: Theme.alpha(s.body, 0.46 * s.strength) }
                }
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.50 * s.strength)
            }
            Rectangle {                                      // specular top edge
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: s.radius * 0.6; rightMargin: s.radius * 0.6; topMargin: 1 }
                height: 1.5
                radius: 1
                color: Qt.rgba(1, 1, 1, 0.85 * s.strength)
            }
            Rectangle {                                      // refraction glow along the bottom
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: s.radius; rightMargin: s.radius; bottomMargin: 2 }
                height: parent.height * 0.3
                radius: height / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.14 * s.strength) }
                }
            }
        }
    }

    Component {
        id: classic
        Item {
            readonly property bool solid: s.strength >= 0.99
            Rectangle {
                anchors.fill: parent
                color: parent.solid ? s.body : Theme.alpha(s.th.face || "#c0c0c0", Math.min(1, s.strength * 2.5))
            }
            // raised bevel: light top-left, dark bottom-right
            Rectangle { visible: !parent.solid; x: 0; y: 0; width: parent.width; height: 1; color: Theme.alpha(s.th.light || "#ffffff", s.strength * 2.5) }
            Rectangle { visible: !parent.solid; x: 0; y: 0; width: 1; height: parent.height; color: Theme.alpha(s.th.light || "#ffffff", s.strength * 2.5) }
            Rectangle { visible: !parent.solid; x: 0; y: parent.height - 1; width: parent.width; height: 1; color: Theme.alpha(s.th.shade || "#808080", s.strength * 2.5) }
            Rectangle { visible: !parent.solid; x: parent.width - 1; y: 0; width: 1; height: parent.height; color: Theme.alpha(s.th.shade || "#808080", s.strength * 2.5) }
        }
    }

    Component {
        id: wii
        Item {
            readonly property bool lit: s.strength >= 0.99
            RectangularShadow {
                visible: parent.lit
                anchors.fill: parent
                radius: s.radius
                blur: 10
                spread: 1
                color: Theme.alpha(s.body, 0.45)
            }
            Rectangle {
                anchors.fill: parent
                radius: s.radius
                color: Qt.rgba(1, 1, 1, Math.min(1, 0.96 * s.strength * (parent.lit ? 1 : 1.6)))
                border.width: parent.lit ? 2 : 1
                border.color: parent.lit ? s.body : Theme.alpha("#9a9a9a", Math.min(1, s.strength * 1.6))
            }
        }
    }

    Component {
        id: nixie
        Item {
            RectangularShadow {
                visible: s.strength > 0.5
                anchors.fill: parent
                radius: s.radius
                blur: 14
                color: Theme.alpha(s.body, 0.35 * s.strength)
            }
            Rectangle {
                anchors.fill: parent
                radius: s.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.alpha(s.body, 0.06 * s.strength) }
                    GradientStop { position: 1.0; color: Theme.alpha(s.body, 0.18 * s.strength) }
                }
                border.width: 1
                border.color: Theme.alpha(s.body, 0.7 * s.strength)
            }
            Rectangle {                                      // the filament, lit
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 6; rightMargin: 6; bottomMargin: 2 }
                height: 1
                color: Theme.alpha(Qt.lighter(s.body, 1.3), 0.8 * s.strength)
            }
        }
    }

    Component {
        id: xmb
        Item {
            Rectangle {
                anchors.fill: parent
                radius: s.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                    GradientStop { position: 0.18; color: Qt.rgba(1, 1, 1, 0.20 * s.strength) }
                    GradientStop { position: 0.8; color: Qt.rgba(1, 1, 1, 0.12 * s.strength) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                }
            }
            Repeater {                                       // hairlines above and below
                model: 2
                Rectangle {
                    required property int index
                    width: parent.width
                    height: 1
                    y: index ? parent.height - 1 : 0
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                        GradientStop { position: 0.3; color: Qt.rgba(1, 1, 1, 0.45 * s.strength) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                    }
                }
            }
        }
    }

    Component {
        id: p5
        Item {
            readonly property bool lit: s.strength >= 0.99
            Rectangle {                                      // the black shadow card
                visible: parent.lit
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.topMargin: 4
                anchors.bottomMargin: -4
                rotation: 1.6
                antialiasing: true
                color: "#000000"
                border.width: 2
                border.color: "#ffffff"
            }
            Rectangle {
                anchors.fill: parent
                rotation: parent.lit ? -1.8 : 0
                antialiasing: true
                color: parent.lit ? s.body : Qt.rgba(1, 1, 1, 0.14 * s.strength)
                border.width: parent.lit ? 0 : 1
                border.color: Theme.alpha(s.body, 0.6 * s.strength)
            }
        }
    }

    Component {
        id: chrome
        Item {
            Rectangle {
                anchors.fill: parent
                radius: s.radius
                gradient: Gradient {
                    GradientStop { position: 0.0;  color: Qt.rgba(1, 1, 1, 0.95 * s.strength) }
                    GradientStop { position: 0.46; color: Theme.alpha("#c9cfd8", 0.95 * s.strength) }
                    GradientStop { position: 0.5;  color: Theme.alpha("#98a1ae", 0.95 * s.strength) }
                    GradientStop { position: 1.0;  color: Theme.alpha("#e8ecf1", 0.95 * s.strength) }
                }
                border.width: 1
                border.color: Theme.alpha("#5b6370", 0.9 * s.strength)
            }
            Rectangle {                                      // iridescent wash
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, s.radius - 1)
                visible: s.strength >= 0.99
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.alpha(s.body, 0.35) }
                    GradientStop { position: 0.5; color: Theme.alpha(Qt.lighter(s.body, 1.4), 0.10) }
                    GradientStop { position: 1.0; color: Theme.alpha(s.th.accent2, 0.35) }
                }
            }
        }
    }
}
