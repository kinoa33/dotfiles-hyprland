// a one-line text input in the theme's field style. `edited` fires when
// you press ⏎ or leave the box, only if the text changed
import QtQuick
import QtQuick.Layouts
import "../common"

Field {
    id: box
    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property bool mono: false                    // glyph font (for nerd-font icons)
    signal edited(string text)
    signal accepted(string text)

    th: Theme.t
    focused: input.activeFocus
    implicitHeight: 30
    Layout.fillWidth: true

    property string last: ""
    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: box.th.text
        selectionColor: Theme.alpha(box.th.accent, 0.45)
        selectedTextColor: box.th.selText
        selectByMouse: true
        font { family: box.mono ? box.th.glyphFont : box.th.font; pixelSize: 13 }
        onActiveFocusChanged: if (activeFocus) box.last = text
        onEditingFinished: if (text !== box.last) { box.last = text; box.edited(text); }
        onAccepted: box.accepted(text)
        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: input.text === "" && !input.activeFocus
            text: box.placeholder
            elide: Text.ElideRight
            color: box.th.faint
            font: input.font
        }
    }
}
