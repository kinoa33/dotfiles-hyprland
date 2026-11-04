// Bar.qml
import QtQuick 2.15

Item {
    id: barRoot
    width: parent.width 
    height: parent.height

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        
        Text {
            anchors.centerIn: parent
            text: "Hello from MyComponent"
            color: "white"
        }
    }
}
