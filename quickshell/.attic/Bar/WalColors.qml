pragma Singleton
import QtQuick

Item {
    id: wal

    visible: false
    property var data: ({})
    property string lastContent: ""

    // exposed colors
    property string background: data.special ? data.special.background : "#1e1e2e"
    property string foreground: data.special ? data.special.foreground : "#ffffff"

    property string color0:  data.colors ? data.colors.color0  : "#000000"
    property string color1:  data.colors ? data.colors.color1  : "#ff5555"
    property string color2:  data.colors ? data.colors.color2  : "#50fa7b"
    property string color3:  data.colors ? data.colors.color3  : "#f1fa8c"
    property string color4:  data.colors ? data.colors.color4  : "#bd93f9"
    property string color5:  data.colors ? data.colors.color5  : "#ff79c6"
    property string color6:  data.colors ? data.colors.color6  : "#8be9fd"
    property string color7:  data.colors ? data.colors.color7  : "#bbbbbb"
    property string color8:  data.colors ? data.colors.color8  : "#44475a"
    property string color9:  data.colors ? data.colors.color9  : "#ff5555"
    property string color10: data.colors ? data.colors.color10 : "#50fa7b"
    property string color11: data.colors ? data.colors.color11 : "#f1fa8c"
    property string color12: data.colors ? data.colors.color12 : "#bd93f9"
    property string color13: data.colors ? data.colors.color13 : "#ff79c6"
    property string color14: data.colors ? data.colors.color14 : "#8be9fd"
    property string color15: data.colors ? data.colors.color15 : "#ffffff"

    function load() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file:///home/gfed/.cache/wal/colors.json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.responseText !== lastContent) {
                    lastContent = xhr.responseText
                    data = JSON.parse(xhr.responseText)
                }
            }
        }
        xhr.send()
    }

    Component.onCompleted: load()

    // Poll every second for live updates
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: wal.load()
    }
}
