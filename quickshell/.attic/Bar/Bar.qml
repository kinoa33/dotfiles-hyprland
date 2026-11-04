import QtQuick 2.15
import "TodoWidget"

Item {
    id: barRoot
    
    // Expose the state so shell0.qml can read it
    property alias isExpanded: todo.isExpanded
    
    // Match the size of the collapsed widget
    implicitWidth: todo.implicitWidth
    implicitHeight: todo.implicitHeight

    TodoWidget {
        id: todo
        anchors.centerIn: parent
    }
}
