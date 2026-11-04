import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.LocalStorage 2.0
import "../"  // Imports WalColors from the parent directory

Item {
    id: root
    
    // The static size the collapsed button takes up inside the bar
    implicitWidth: 100
    implicitHeight: 24

    property bool isExpanded: false

    // ==========================================
    // MAIN BACKGROUND (The Dropdown)
    // ==========================================
    Rectangle {
        id: bgRect
        
        // Anchor to the top right of the layout slot so it drops downwards
        anchors.top: parent.top
        anchors.right: parent.right
        
        width: root.isExpanded ? 300 : root.implicitWidth
        height: root.isExpanded ? 400 : root.implicitHeight
        
        radius: root.isExpanded ? 18 : 6
        color: WalColors.background
        opacity: root.isExpanded ? 0.95 : 1.0
        border.color: root.isExpanded ? "transparent" : WalColors.color4
        border.width: root.isExpanded ? 0 : 2

        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
        Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
        Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

        // ==========================================
        // COLLAPSED CONTENT (The Button)
        // ==========================================
        Item {
            width: root.implicitWidth
            height: root.implicitHeight
            anchors.top: parent.top
            anchors.right: parent.right
            
            opacity: root.isExpanded ? 0 : 1
            visible: opacity > 0 
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Text {
                anchors.centerIn: parent
                text: "📋 Tasks"
                font.pixelSize: 14
                color: WalColors.foreground
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: !root.isExpanded 
                onClicked: root.isExpanded = true
            }
        }

        // ==========================================
        // EXPANDED CONTENT (The TODO List)
        // ==========================================
        Item {
            anchors.fill: parent
            opacity: root.isExpanded ? 1 : 0
            visible: opacity > 0
            
            Behavior on opacity { 
                SequentialAnimation {
                    PauseAnimation { duration: root.isExpanded ? 150 : 0 }
                    NumberAnimation { duration: 300 }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            Button {
                text: "✖"
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 12
                z: 2
                background: Rectangle { color: "transparent" }
                contentItem: Text {
                    text: parent.text
                    color: WalColors.foreground
                    font.pixelSize: 16
                }
                onClicked: root.isExpanded = false
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Text {
                    text: "TODO List"
                    color: WalColors.foreground
                    font.pixelSize: 24
                    Layout.alignment: Qt.AlignHCenter
                }

                RowLayout {
                    spacing: 6
                    TextField {
                        id: taskInput
                        placeholderText: "New task..."
                        font.pixelSize: 16
                        Layout.fillWidth: true
                        color: WalColors.foreground
                        background: Rectangle {
                            color: "transparent"
                            border.color: WalColors.foreground
                            radius: 6
                        }
                        onAccepted: {
                            addTask()
                            root.isExpanded = false
                        }
                    }
                    Button { text: "Add"; onClicked: addTask() }
                }

                ListView {
                    id: taskList
                    model: tasksModel
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    delegate: RowLayout {
                        spacing: 6
                        width: taskList.width
                        CheckBox {
                            checked: done
                            onCheckedChanged: { done = checked; saveTasks() }
                        }
                        Text {
                            text: model.text
                            color: done ? "gray" : WalColors.foreground
                            font.pixelSize: 16
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                        Button {
                            text: "✕"
                            onClicked: { tasksModel.remove(index); saveTasks() }
                            font.pixelSize: 14
                            background: Rectangle { color: "transparent" }
                            contentItem: Text { text: parent.text; color: WalColors.color1 }
                            padding: 2
                        }
                    }
                }
                ListModel { id: tasksModel }
            }
        }
    }

    // Storage Functions
    function addTask() {
        if(taskInput.text !== "") {
            tasksModel.append({"text": taskInput.text, "done": false})
            saveTasks()
            taskInput.text = ""
        }
    }
    function saveTasks() {
        var db = LocalStorage.openDatabaseSync("todoDB", "1.0", "TODO List DB", 1000000)
        db.transaction(function(tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS tasks(text TEXT, done INT)")
            tx.executeSql("DELETE FROM tasks")
            for (var i=0; i<tasksModel.count; i++) {
                var item = tasksModel.get(i)
                tx.executeSql("INSERT INTO tasks VALUES(?, ?)", [item.text, item.done ? 1 : 0])
            }
        })
    }
    Component.onCompleted: {
        var db = LocalStorage.openDatabaseSync("todoDB", "1.0", "TODO List DB", 1000000)
        db.transaction(function(tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS tasks(text TEXT, done INT)")
            var rs = tx.executeSql("SELECT * FROM tasks")
            for (var i=0; i<rs.rows.length; i++) {
                var row = rs.rows.item(i)
                tasksModel.append({"text": row.text, "done": row.done === 1})
            }
        })
    }
}
