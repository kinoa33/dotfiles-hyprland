// the blurred wallpaper under a glass surface — what Hyprland's blur does
// on the real desktop. `glass` comes from the stage: { source, stage, rev }
// (source: the stage's blurred wallpaper; rev bumps when the layout moves)
import QtQuick
import Quickshell.Widgets

ClippingRectangle {
    id: g
    property var glass: null
    color: "transparent"
    visible: glass !== null
    property rect area: Qt.rect(0, 0, 1, 1)

    function update() {
        if (!glass || !glass.stage) return;
        const p = g.mapToItem(glass.stage, 0, 0);
        const q = g.mapToItem(glass.stage, g.width, g.height);
        area = Qt.rect(p.x, p.y, Math.max(1, q.x - p.x), Math.max(1, q.y - p.y));
    }
    readonly property int rev: glass ? glass.rev : 0
    onRevChanged: Qt.callLater(update)
    onWidthChanged: Qt.callLater(update)
    onHeightChanged: Qt.callLater(update)
    Component.onCompleted: Qt.callLater(update)

    ShaderEffectSource {
        anchors.fill: parent
        sourceItem: g.glass ? g.glass.source : null
        sourceRect: g.area
    }
}
