// a colour chip over a checkerboard, so transparency shows
import QtQuick
import "../common"

Item {
    id: sw
    property var th: Theme.t
    property color color: "transparent"
    property real radius: 5
    property bool picked: false                  // a ring when it's the chosen one
    implicitWidth: 22
    implicitHeight: 22

    Rectangle {                                  // checkerboard (2 tones + a cached grid)
        anchors.fill: parent
        radius: sw.radius
        color: "#bfbfbf"
        clip: true
        Canvas {
            anchors.fill: parent
            visible: sw.color.a < 0.999
            onPaint: {
                const ctx = getContext("2d");
                ctx.fillStyle = "#7f7f7f";
                for (let y = 0; y < height; y += 5)
                    for (let x = (y / 5) % 2 * 5; x < width; x += 10)
                        ctx.fillRect(x, y, 5, 5);
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: sw.radius
        color: sw.color
        border.width: 1
        border.color: Theme.alpha(sw.th.text, 0.35)
    }
    Rectangle {
        visible: sw.picked
        anchors.fill: parent
        anchors.margins: -3
        radius: sw.radius + 3
        color: "transparent"
        border.width: 2
        border.color: sw.th.ink
    }
}
