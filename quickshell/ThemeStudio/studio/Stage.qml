// the preview: the theme being edited, worn by stand-ins of every widget.
//   show "all"   a virtual 1920×1080 desktop — bar, launcher, todo,
//                control center and notifications where they really sit
//   show <key>   one widget, at its real size (shrunk to fit)
// backdrop "wallpaper" puts your wallpaper behind it and blurs it under
// each glass surface (like hyprland does); "dark"/"light" are plain, to
// judge a theme over the worst cases.
import QtQuick
import QtQuick.Effects
import "../common"

Item {
    id: st
    property var th: Theme.t
    property var ed                             // the studio editor: tokensFor(widget)
    property string show: "all"
    property string backdrop: "wallpaper"
    property bool animate: true
    property var thumbs: []
    property bool stock: false                  // "rice" untouched (bar/dunst keep their own css)
    clip: true

    property int rev: 0
    function bump() { Qt.callLater(() => st.rev++); }
    onWidthChanged: bump()
    onHeightChanged: bump()
    onShowChanged: bump()
    onBackdropChanged: bump()
    readonly property var glass: backdrop === "wallpaper" && wall.status === Image.Ready
                                 ? ({ source: blurred, stage: st, rev: rev }) : null

    Rectangle {
        anchors.fill: parent
        color: st.backdrop === "light" ? "#c8c8cd" : "#17171b"
    }
    Image {
        id: wall
        anchors.fill: parent
        visible: st.backdrop === "wallpaper"
        source: WalColors.wallpaper ? "file://" + WalColors.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 1920
        asynchronous: true
        onStatusChanged: st.bump()
    }
    MultiEffect {                                   // sampled by every GlassUnder
        id: blurred
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blur: 1.0
        blurMax: 40
        visible: false
    }

    // ── the whole desktop ────────────────────────────────────────
    Loader {
        id: desk
        active: st.show === "all"
        width: 1920
        height: 1080
        scale: Math.min(st.width / 1920, st.height / 1080)
        transformOrigin: Item.TopLeft
        x: (st.width - 1920 * scale) / 2
        y: (st.height - 1080 * scale) / 2
        onLoaded: st.bump()
        sourceComponent: Item {
            BarMock {
                x: 12; y: 6; width: 1896
                th: st.ed.tokensFor("waybar"); glass: st.glass; animate: st.animate; stock: st.stock
            }
            TodoMock {
                x: 70; y: 300
                th: st.ed.tokensFor("todo"); glass: st.glass; animate: st.animate
            }
            LauncherMock {
                x: 600; y: 150
                th: st.ed.tokensFor("launcher"); glass: st.glass; animate: st.animate
            }
            NotifyMock {
                x: 1528; y: 58
                th: st.ed.tokensFor("notifications"); glass: st.glass; animate: st.animate; stock: st.stock
            }
            CenterMock {
                x: 1460; y: 440
                th: st.ed.tokensFor("controlcenter"); glass: st.glass; animate: st.animate
            }
        }
    }

    // ── one widget ───────────────────────────────────────────────
    Loader {
        id: one
        active: st.show !== "all"
        anchors.fill: parent
        onLoaded: st.bump()
        sourceComponent: Item {
            id: box
            property real nw: 1                     // the mock's natural size
            property real nh: 1
            readonly property real k: Math.min(1, (box.width - 80) / nw, (box.height - 80) / nh)
            Loader {
                id: mockLoader
                width: box.nw
                height: box.nh
                scale: box.k
                transformOrigin: Item.TopLeft
                x: (box.width - box.nw * box.k) / 2
                y: (box.height - box.nh * box.k) / 2
                onXChanged: st.bump()
                onScaleChanged: st.bump()
                sourceComponent: {
                    switch (st.show) {
                    case "waybar":        return barOne;
                    case "notifications": return notifyOne;
                    case "wallpicker":    return wallOne;
                    case "todo":          return todoOne;
                    case "controlcenter": return centerOne;
                    case "screenshot":    return shotOne;
                    default:              return launcherOne;
                    }
                }
                onLoaded: {
                    const mock = item as Item;
                    box.nw = mock ? mock.implicitWidth : 1;
                    box.nh = mock ? mock.implicitHeight : 1;
                    st.bump();
                }
            }
        }
    }
    Component { id: launcherOne; LauncherMock { th: st.ed.tokensFor("launcher"); glass: st.glass; animate: st.animate } }
    Component { id: barOne;      BarMock { th: st.ed.tokensFor("waybar"); glass: st.glass; animate: st.animate; stock: st.stock } }
    Component { id: notifyOne;   NotifyMock { th: st.ed.tokensFor("notifications"); glass: st.glass; animate: st.animate; stock: st.stock } }
    Component { id: wallOne;     WallMock { th: st.ed.tokensFor("wallpicker"); glass: st.glass; animate: st.animate; thumbs: st.thumbs } }
    Component { id: todoOne;     TodoMock { th: st.ed.tokensFor("todo"); glass: st.glass; animate: st.animate } }
    Component { id: centerOne;   CenterMock { th: st.ed.tokensFor("controlcenter"); glass: st.glass; animate: st.animate } }
    Component { id: shotOne;     ShotMock { th: st.ed.tokensFor("screenshot"); glass: st.glass; animate: st.animate } }
}
