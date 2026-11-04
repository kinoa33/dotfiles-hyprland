// a footer key hint: [key] label
import QtQuick
import "."

Item {
    id: key
    property var th: Theme.t
    property string keys
    property string label
    implicitWidth: row.implicitWidth
    implicitHeight: 20

    Row {
        id: row
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter
        Item {
            width: cap.implicitWidth + 12
            height: 19
            Surface {
                anchors.fill: parent
                th: key.th
                radius: Math.min(5, key.th.radiusSm)
                tint: key.th.text
                strength: 0.32
            }
            Text {
                id: cap
                anchors.centerIn: parent
                text: key.keys
                color: key.th.text
                font { family: key.th.font; pixelSize: 10 }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: key.label
            color: key.th.dim
            font { family: key.th.font; pixelSize: 11 }
        }
    }
}
