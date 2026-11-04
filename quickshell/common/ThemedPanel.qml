// the glass slab every widget sits on, dressed by the theme:
// body gradient, border, inner rim, sheen, and the living layer
// behind the content:
//   bubbles (aero) · grid (vaporwave) · scanlines (phosphor) ·
//   blobs (frost) · banner (rice: the wallpaper itself) ·
//   petals (sakura) · aurora (aurora) · titlebar (classic, luna) ·
//   sweep (dark aero, chrome) · eco · wii · divergence (steins;gate) ·
//   wave (ps3) · xbox · dmg (game boy) · p5 (persona)
//
// everything that moves runs on Animators (render thread) over
// cached textures, and only while `animate` is true and motion is on.
// hosts pad their content by `topInset` (the classic title bar).
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Widgets
import "."

Item {
    id: panel
    property var th: Theme.t
    property real radius: th.radius
    property bool animate: true
    property string title: ""                       // shown in the classic title bar
    readonly property bool running: animate && Theme.motion && visible && opacity > 0
    readonly property int topInset: th.fx === "titlebar" ? (th.titleStyle === "luna" ? 24 : 26) : 0
    default property alias content: inner.data

    RectangularShadow {
        anchors.fill: body
        radius: body.radius
        blur: 30
        spread: 2
        offset: Qt.vector2d(0, 7)
        color: Qt.rgba(0.01, 0.02, 0.04, panel.th.shadow)
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: panel.radius
        gradient: Gradient {
            GradientStop { position: 0.0;  color: panel.th.panelTop }
            GradientStop { position: 0.24; color: panel.th.panelMid }
            GradientStop { position: 1.0;  color: panel.th.panelBottom }
        }
        border.width: panel.th.bevel ? 0 : 1
        border.color: panel.th.panelBorder
    }

    // the wallpaper, as a band across the top (rice)
    Loader {
        active: panel.th.fx === "banner" && WalColors.wallpaper !== ""
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
        height: Math.min(170, parent.height * 0.42)
        sourceComponent: ClippingRectangle {
            radius: Math.max(0, panel.radius - 1)
            color: "transparent"
            Image {
                anchors.fill: parent
                source: "file://" + WalColors.wallpaper
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 960
                asynchronous: true
                opacity: 0.5
            }
            Rectangle {                                     // fade into the glass
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.alpha(panel.th.panelTop, 0.15) }
                    GradientStop { position: 0.6; color: Theme.alpha(panel.th.panelMid, 0.7) }
                    GradientStop { position: 1.0; color: panel.th.panelMid }
                }
            }
        }
    }

    // ── the living layer ─────────────────────────────────────────
    Loader {
        anchors.fill: parent
        anchors.margins: Math.max(2, panel.radius / 3)
        anchors.topMargin: Math.max(2, panel.radius / 3) + panel.topInset
        sourceComponent: {
            switch (panel.th.fx) {
            case "bubbles":   return bubblesFx;
            case "grid":      return gridFx;
            case "scanlines": return beamFx;
            case "blobs":     return blobsFx;
            case "petals":    return petalsFx;
            case "aurora":    return auroraFx;
            case "sweep":     return sweepFx;
            case "eco":       return ecoFx;
            case "wii":       return wiiFx;
            case "divergence": return divergenceFx;
            case "wave":      return waveFx;
            case "xbox":      return xboxFx;
            case "p5":        return p5Fx;
            default:          return null;
            }
        }
    }

    // aurora swoosh low across the glass (aero)
    Shape {
        anchors.fill: parent
        visible: panel.th.swoosh
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0; y1: 0
                x2: panel.width; y2: 0
                GradientStop { position: 0.0; color: Theme.alpha(panel.th.accent, 0.0) }
                GradientStop { position: 0.45; color: Theme.alpha(Qt.lighter(panel.th.accent, 1.3), 0.24) }
                GradientStop { position: 1.0; color: Theme.alpha(panel.th.accent2, 0.20) }
            }
            startX: 0; startY: panel.height * 0.80
            PathCubic {
                x: panel.width; y: panel.height * 0.66
                control1X: panel.width * 0.35; control1Y: panel.height * 0.62
                control2X: panel.width * 0.62; control2Y: panel.height * 0.98
            }
            PathLine { x: panel.width; y: panel.height * 0.76 }
            PathCubic {
                x: 0; y: panel.height * 0.90
                control1X: panel.width * 0.62; control1Y: panel.height * 1.06
                control2X: panel.width * 0.35; control2Y: panel.height * 0.72
            }
            PathLine { x: 0; y: panel.height * 0.80 }
        }
    }

    // sheen across the top (aero, frost, sakura, liquid)
    Rectangle {
        visible: panel.th.sheen
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
        height: Math.min(120, parent.height * 0.4)
        radius: Math.max(0, panel.radius - 1)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, panel.th.dark ? 0.16 : 0.45) }
            GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, panel.th.dark ? 0.04 : 0.10) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
        }
    }
    // one diagonal streak of light (aero)
    Item {
        visible: panel.th.streak
        anchors.fill: parent
        anchors.leftMargin: panel.radius + 6
        anchors.rightMargin: panel.radius + 6
        clip: true
        Rectangle {
            x: parent.width * 0.58
            y: -60
            width: 70
            height: 260
            rotation: 28
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.07) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
    }
    // neon hairline along the top edge (neon)
    Rectangle {
        visible: panel.th.hairline
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.6
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Theme.alpha(panel.th.accent, 0.85) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    // lens edges: a bright specular arc on top, a faint one below (liquid)
    Item {
        visible: panel.th.edge
        anchors.fill: parent
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: panel.radius; rightMargin: panel.radius; topMargin: 1 }
            height: 2
            radius: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.2) }
                GradientStop { position: 0.3; color: Qt.rgba(1, 1, 1, 0.95) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.15) }
            }
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: panel.radius; rightMargin: panel.radius; bottomMargin: 1 }
            height: 1.5
            radius: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.05) }
                GradientStop { position: 0.7; color: Qt.rgba(1, 1, 1, 0.45) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.1) }
            }
        }
    }
    // inner rim just inside the border
    Rectangle {
        visible: !panel.th.bevel
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, panel.radius - 1)
        color: "transparent"
        border.width: 1
        border.color: panel.th.rim
    }
    // classic: a raised window frame, two pixels of bevel each side
    Item {
        visible: panel.th.bevel
        anchors.fill: parent
        Rectangle { x: 0; y: 0; width: parent.width; height: 1; color: panel.th.light || "#ffffff" }
        Rectangle { x: 0; y: 0; width: 1; height: parent.height; color: panel.th.light || "#ffffff" }
        Rectangle { x: 1; y: 1; width: parent.width - 2; height: 1; color: Qt.lighter(panel.th.face || "#c0c0c0", 1.1) }
        Rectangle { x: 1; y: 1; width: 1; height: parent.height - 2; color: Qt.lighter(panel.th.face || "#c0c0c0", 1.1) }
        Rectangle { x: 0; y: parent.height - 1; width: parent.width; height: 1; color: "#000000" }
        Rectangle { x: parent.width - 1; y: 0; width: 1; height: parent.height; color: "#000000" }
        Rectangle { x: 1; y: parent.height - 2; width: parent.width - 2; height: 1; color: panel.th.shade || "#808080" }
        Rectangle { x: parent.width - 2; y: 1; width: 1; height: parent.height - 2; color: panel.th.shade || "#808080" }
    }
    // classic / luna: the title bar
    Rectangle {
        readonly property bool luna: panel.th.titleStyle === "luna"
        visible: panel.th.fx === "titlebar"
        x: luna ? 1 : 3; y: luna ? 1 : 3
        width: parent.width - (luna ? 2 : 6)
        height: luna ? 24 : 22
        topLeftRadius: luna ? panel.radius - 1 : 0
        topRightRadius: luna ? panel.radius - 1 : 0
        gradient: luna ? lunaBar : classicBar
        Gradient {
            id: classicBar
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: panel.th.accent }
            GradientStop { position: 1.0; color: panel.th.accent2 }
        }
        Gradient {
            id: lunaBar
            GradientStop { position: 0.0;  color: Qt.lighter(panel.th.xp || "#0a5ee0", 1.45) }
            GradientStop { position: 0.12; color: Qt.lighter(panel.th.xp || "#0a5ee0", 1.15) }
            GradientStop { position: 0.55; color: panel.th.xp || "#0a5ee0" }
            GradientStop { position: 1.0;  color: Qt.darker(panel.th.xp || "#0a5ee0", 1.25) }
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: panel.title
            color: "white"
            font { family: panel.th.font; pixelSize: 12; bold: true }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Repeater {
                model: ["󰖰", "󰖯", "󰅖"]
                Item {
                    id: tbtn
                    required property string modelData
                    required property int index
                    readonly property bool luna: panel.th.titleStyle === "luna"
                    width: luna ? 19 : 18
                    height: luna ? 19 : 16
                    Surface { visible: !tbtn.luna; anchors.fill: parent; th: panel.th; strength: 0.4 }
                    Rectangle {
                        visible: tbtn.luna
                        anchors.fill: parent
                        radius: 3
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: tbtn.index === 2 ? "#f08c6c" : "#5e9bff" }
                            GradientStop { position: 1.0; color: tbtn.index === 2 ? "#c8381c" : "#1a55d6" }
                        }
                        border.width: 1
                        border.color: "#ffffff"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: tbtn.modelData
                        color: tbtn.luna ? "#ffffff" : "#000000"
                        font { family: panel.th.glyphFont; pixelSize: tbtn.luna ? 11 : 10 }
                    }
                }
            }
        }
    }

    Item {
        id: inner
        anchors.fill: parent
    }

    // crt scanlines sit over the content, faintly (phosphor)
    Canvas {
        anchors.fill: parent
        anchors.margins: 1
        visible: panel.th.fx === "scanlines"
        opacity: 0.55
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = "rgba(0, 0, 0, 0.32)";
            for (let y = 0; y < height; y += 3) ctx.fillRect(0, y, width, 1);
        }
    }

    // game boy: the lcd's dot matrix, over everything, faintly
    Canvas {
        anchors.fill: parent
        anchors.margins: 1
        visible: panel.th.fx === "dmg"
        opacity: 0.5
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = "rgba(15, 56, 15, 0.10)";
            for (let y = 0; y < height; y += 3) ctx.fillRect(0, y, width, 1);
            for (let x = 0; x < width; x += 3) ctx.fillRect(x, 0, 1, height);
        }
    }

    // ══ fx ═══════════════════════════════════════════════════════

    // a band of light sweeping across the glass every few seconds (dark aero, chrome)
    Component {
        id: sweepFx
        Item {
            id: swp
            clip: true
            Rectangle {
                id: shine
                width: Math.max(80, swp.width * 0.28)
                height: swp.height * 2.4
                y: -swp.height * 0.7
                x: -width * 2
                rotation: 22
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                    GradientStop { position: 0.5; color: panel.th.dark ? Qt.rgba(1, 1, 1, 0.09) : Theme.alpha(panel.th.accent, 0.22) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                }
            }
            SequentialAnimation {
                running: panel.running
                loops: Animation.Infinite
                PauseAnimation { duration: 3400 }
                XAnimator { target: shine; from: -shine.width * 2; to: swp.width + shine.width; duration: 2600; easing.type: Easing.InOutSine }
            }
        }
    }

    // sunbeams from the top-left, leaves drifting down (frutiger eco)
    Component {
        id: ecoFx
        Item {
            id: eco
            clip: true
            Repeater {
                model: 4
                Rectangle {
                    id: beam
                    required property int index
                    x: -30 + index * 46
                    y: -40
                    width: 40 + index * 16
                    height: eco.height * 1.7
                    rotation: -32 + index * 9
                    transformOrigin: Item.Top
                    opacity: 0.16 - index * 0.025
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 0.92, 1) }
                        GradientStop { position: 0.75; color: Qt.rgba(1, 1, 1, 0.0) }
                    }
                    SequentialAnimation on opacity {
                        running: panel.running
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.06; duration: 4200 + beam.index * 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.16 - beam.index * 0.025; duration: 4200 + beam.index * 900; easing.type: Easing.InOutSine }
                    }
                }
            }
            Loader { anchors.fill: parent; sourceComponent: petalsFx }        // the accent is green: leaves
        }
    }

    // the wii menu's faint pinstripes
    Component {
        id: wiiFx
        Canvas {
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = "rgba(0, 0, 0, 0.035)";
                for (let y = 0; y < height; y += 4) ctx.fillRect(0, y, width, 2);
            }
        }
    }

    // the divergence meter, flickering between world lines; brass cogs turning (steins;gate)
    Component {
        id: divergenceFx
        Item {
            id: dv
            clip: true
            property string reading: "1.048596"
            function worldline() {
                let s = Math.random() < 0.5 ? "0." : "1.";
                for (let i = 0; i < 6; i++) s += Math.floor(Math.random() * 10);
                return s;
            }
            // low and to the right, sized to the panel: clear of every header
            Text {
                id: meter
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 8
                anchors.bottomMargin: 58                // above every widget's footer
                text: dv.reading
                color: Theme.alpha(panel.th.accent, 0.12)
                font { family: panel.th.font; pixelSize: Math.round(Math.max(26, Math.min(56, dv.width * 0.075))); letterSpacing: Math.round(meter.font.pixelSize * 0.12) }
                style: Text.Outline
                styleColor: Theme.alpha(panel.th.accent, 0.10)
            }
            Timer {
                running: panel.running
                interval: 5600
                repeat: true
                onTriggered: flicker.restart()
            }
            SequentialAnimation {
                id: flicker
                ScriptAction { script: dv.reading = dv.worldline() }
                PauseAnimation { duration: 110 }
                ScriptAction { script: dv.reading = dv.worldline() }
                PauseAnimation { duration: 110 }
                ScriptAction { script: dv.reading = dv.worldline() }
                PauseAnimation { duration: 140 }
                ScriptAction { script: dv.reading = "1.048596" }
            }
            Repeater {
                model: [ { s: 170, x: -60, y: 0.58, d: 60000 }, { s: 96, x: 70, y: 0.80, d: -40000 } ]
                Text {
                    id: cog
                    required property var modelData
                    x: modelData.x
                    y: dv.height * modelData.y - cog.modelData.s * 0.2
                    text: "󰒓"
                    color: Theme.alpha(panel.th.accent, 0.06)
                    font { family: panel.th.glyphFont; pixelSize: cog.modelData.s }
                    RotationAnimator on rotation {
                        running: panel.running
                        from: 0
                        to: cog.modelData.d > 0 ? 360 : -360
                        duration: Math.abs(cog.modelData.d)
                        loops: Animation.Infinite
                    }
                }
            }
        }
    }

    // the xmb wave: soft white ribbons drifting across (ps3)
    Component {
        id: waveFx
        Item {
            id: wv
            clip: true
            property real phase: 0
            NumberAnimation on phase {
                running: panel.running
                from: 0
                to: Math.PI * 2
                duration: 16000
                loops: Animation.Infinite
            }
            // a ribbon: sine top edge, a breathing thickness underneath
            function band(base, amp, freq, off, thick) {
                const n = 36, top = [], bot = [];
                for (let i = 0; i <= n; i++) {
                    const u = i / n, x = wv.width * u;
                    const y = wv.height * base + amp * Math.sin(freq * u * Math.PI * 2 + wv.phase + off);
                    top.push(Qt.point(x, y));
                    bot.push(Qt.point(x, y + thick * (0.55 + 0.45 * Math.sin(u * Math.PI * 2 + wv.phase * 2 + off))));
                }
                return top.concat(bot.reverse(), [top[0]]);
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: wv.width; y2: 0
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.13) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.02) }
                    }
                    PathPolyline { path: wv.band(0.56, 26, 1.0, 0.0, 30) }
                }
                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: wv.width; y2: 0
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.02) }
                        GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0.09) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                    }
                    PathPolyline { path: wv.band(0.60, 34, 0.8, 1.7, 18) }
                }
                ShapePath {
                    strokeColor: Qt.rgba(1, 1, 1, 0.22)
                    strokeWidth: 1
                    fillColor: "transparent"
                    PathPolyline { path: wv.band(0.58, 30, 1.2, 3.1, 0).slice(0, 37) }
                }
            }
            Repeater {                                      // sparkles
                model: 10
                Rectangle {
                    id: spark
                    required property int index
                    width: 2; height: 2; radius: 1
                    color: "white"
                    x: ((index * 211 + 37) % 997) / 997 * wv.width
                    y: wv.height * (0.45 + ((index * 131) % 97) / 97 * 0.3)
                    opacity: 0.2
                    SequentialAnimation {
                        running: panel.running
                        loops: Animation.Infinite
                        PauseAnimation { duration: (spark.index * 547) % 3000 }
                        OpacityAnimator { target: spark; from: 0.1; to: 0.8; duration: 1500 }
                        OpacityAnimator { target: spark; from: 0.8; to: 0.1; duration: 1800 }
                    }
                }
            }
        }
    }

    // a green glow and the ring of light, turning slowly (xbox 360)
    Component {
        id: xboxFx
        Item {
            id: xb
            clip: true
            RectangularShadow {
                width: xb.width * 0.7
                height: xb.height * 0.5
                x: xb.width * 0.45
                y: xb.height * 0.62
                radius: height / 2
                blur: 80
                color: Theme.alpha(panel.th.accent, 0.26)
            }
            Item {
                id: ring
                width: 130
                height: 130
                x: xb.width - 160
                y: xb.height - 160
                opacity: 0.2
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: panel.th.accent
                        strokeWidth: 8
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathAngleArc { centerX: 65; centerY: 65; radiusX: 52; radiusY: 52; startAngle: 10; sweepAngle: 70 }
                    }
                    ShapePath {
                        strokeColor: panel.th.accent
                        strokeWidth: 8
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathAngleArc { centerX: 65; centerY: 65; radiusX: 52; radiusY: 52; startAngle: 100; sweepAngle: 70 }
                    }
                    ShapePath {
                        strokeColor: panel.th.accent
                        strokeWidth: 8
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathAngleArc { centerX: 65; centerY: 65; radiusX: 52; radiusY: 52; startAngle: 190; sweepAngle: 70 }
                    }
                    ShapePath {
                        strokeColor: panel.th.accent
                        strokeWidth: 8
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathAngleArc { centerX: 65; centerY: 65; radiusX: 52; radiusY: 52; startAngle: 280; sweepAngle: 70 }
                    }
                }
                RotationAnimator on rotation {
                    running: panel.running
                    from: 0
                    to: 360
                    duration: 24000
                    loops: Animation.Infinite
                }
            }
        }
    }

    // halftone dots and two slashes (persona 5)
    Component {
        id: p5Fx
        Item {
            id: pf
            clip: true
            Canvas {
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    const c = Qt.color(String(panel.th.accent));
                    ctx.fillStyle = "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + ",0.30)";
                    const diag = Math.hypot(width, height);
                    for (let y = 0; y < height; y += 10)
                        for (let x = 0; x < width; x += 10) {
                            const d = Math.hypot(width - x, height - y) / diag;
                            const r = 3.4 * (1 - d / 0.55);
                            if (r <= 0.3) continue;
                            ctx.beginPath();
                            ctx.arc(x + (y / 10 % 2) * 5, y, r, 0, Math.PI * 2);
                            ctx.fill();
                        }
                }
            }
            Rectangle {
                x: pf.width * 0.70; y: -pf.height * 0.3
                width: 30; height: pf.height * 1.7
                rotation: 28
                color: Theme.alpha(panel.th.accent, 0.16)
            }
            Rectangle {
                x: pf.width * 0.77; y: -pf.height * 0.3
                width: 4; height: pf.height * 1.7
                rotation: 28
                color: Qt.rgba(1, 1, 1, 0.10)
            }
        }
    }

    // soap bubbles drifting up (aero) — cached textures moved by animators
    Component {
        id: bubblesFx
        Item {
            id: fx
            clip: true
            Repeater {
                model: 9
                delegate: Item {
                    id: lane
                    required property int index
                    readonly property real size: 8 + (index * 53) % 24
                    readonly property int dur: 13000 + (index * 2300) % 8000
                    width: size
                    height: size
                    x: 6 + ((index * 137 + 31) % 100) / 100 * Math.max(0, fx.width - size - 12)
                    y: fx.height
                    opacity: 0

                    Item {
                        id: bubble
                        width: lane.size
                        height: lane.size
                        layer.enabled: true
                        layer.smooth: true
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.03) }
                                GradientStop { position: 0.7; color: Theme.alpha(panel.th.accent, 0.10) }
                                GradientStop { position: 1.0; color: Theme.alpha(Qt.lighter(panel.th.accent, 1.4), 0.32) }
                            }
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.55)
                        }
                        Rectangle {
                            x: lane.size * 0.18
                            y: lane.size * 0.12
                            width: lane.size * 0.44
                            height: lane.size * 0.26
                            radius: height / 2
                            rotation: -28
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.9) }
                                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                            }
                        }
                        SequentialAnimation {
                            running: panel.running
                            loops: Animation.Infinite
                            XAnimator { target: bubble; from: -8; to: 8; duration: lane.dur / 5; easing.type: Easing.InOutSine }
                            XAnimator { target: bubble; from: 8; to: -8; duration: lane.dur / 5; easing.type: Easing.InOutSine }
                        }
                    }

                    SequentialAnimation {
                        running: panel.running
                        loops: Animation.Infinite
                        PauseAnimation { duration: (lane.index * 1900) % 9000 }
                        ParallelAnimation {
                            YAnimator {
                                target: lane
                                from: fx.height + lane.size
                                to: -lane.size
                                duration: lane.dur
                                easing.type: Easing.InOutSine
                            }
                            SequentialAnimation {
                                OpacityAnimator { target: lane; from: 0; to: 0.85; duration: 1800 }
                                PauseAnimation { duration: lane.dur - 4600 }
                                OpacityAnimator { target: lane; from: 0.85; to: 0; duration: 2800 }
                            }
                        }
                    }
                }
            }
        }
    }

    // blossom petals tumbling down (sakura)
    Component {
        id: petalsFx
        Item {
            id: pfx
            clip: true
            Repeater {
                model: 10
                delegate: Item {
                    id: drop
                    required property int index
                    readonly property real size: 9 + (index * 37) % 9
                    readonly property int dur: 11000 + (index * 2700) % 9000
                    width: size
                    height: size
                    x: 6 + ((index * 113 + 17) % 100) / 100 * Math.max(0, pfx.width - size - 12)
                    y: -size
                    opacity: 0

                    Item {
                        id: petal
                        width: drop.size
                        height: drop.size * 0.62
                        layer.enabled: true
                        layer.smooth: true
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.lighter(panel.th.accent, 1.25) }
                                GradientStop { position: 1.0; color: Theme.alpha(panel.th.accent, 0.85) }
                            }
                        }
                        Rectangle {                         // the notch at the tip
                            x: parent.width - 3
                            y: parent.height / 2 - 1
                            width: 4
                            height: 2
                            radius: 1
                            color: panel.th.panelMid
                        }
                        SequentialAnimation {
                            running: panel.running
                            loops: Animation.Infinite
                            ParallelAnimation {
                                XAnimator { target: petal; from: -14; to: 14; duration: drop.dur / 4; easing.type: Easing.InOutSine }
                                RotationAnimator { target: petal; from: -40; to: 60; duration: drop.dur / 4; easing.type: Easing.InOutSine }
                            }
                            ParallelAnimation {
                                XAnimator { target: petal; from: 14; to: -14; duration: drop.dur / 4; easing.type: Easing.InOutSine }
                                RotationAnimator { target: petal; from: 60; to: -40; duration: drop.dur / 4; easing.type: Easing.InOutSine }
                            }
                        }
                    }

                    SequentialAnimation {
                        running: panel.running
                        loops: Animation.Infinite
                        PauseAnimation { duration: (drop.index * 1700) % 8000 }
                        ParallelAnimation {
                            YAnimator { target: drop; from: -drop.size; to: pfx.height + drop.size; duration: drop.dur }
                            SequentialAnimation {
                                OpacityAnimator { target: drop; from: 0; to: 0.9; duration: 1400 }
                                PauseAnimation { duration: drop.dur - 3800 }
                                OpacityAnimator { target: drop; from: 0.9; to: 0; duration: 2400 }
                            }
                        }
                    }
                }
            }
        }
    }

    // stars twinkling over drifting curtains of light (aurora)
    Component {
        id: auroraFx
        Item {
            id: afx
            clip: true
            Repeater {                                      // curtains
                model: [
                    { c: panel.th.accent,  y: 0.10, w: 0.9, h: 0.22, dx: 60, d: 16000 },
                    { c: panel.th.accent2, y: 0.26, w: 0.7, h: 0.18, dx: -70, d: 21000 }
                ]
                delegate: Item {
                    id: curtain
                    required property var modelData
                    width: afx.width * modelData.w
                    height: afx.height * modelData.h
                    x: (afx.width - width) / 2
                    y: afx.height * modelData.y
                    RectangularShadow {
                        id: glowBand
                        width: curtain.width
                        height: curtain.height
                        radius: height / 2
                        blur: 46
                        color: Theme.alpha(curtain.modelData.c, 0.30)
                    }
                    SequentialAnimation {
                        running: panel.running
                        loops: Animation.Infinite
                        XAnimator { target: glowBand; from: -curtain.modelData.dx; to: curtain.modelData.dx; duration: curtain.modelData.d; easing.type: Easing.InOutSine }
                        XAnimator { target: glowBand; from: curtain.modelData.dx; to: -curtain.modelData.dx; duration: curtain.modelData.d; easing.type: Easing.InOutSine }
                    }
                }
            }
            Repeater {                                      // stars
                model: 26
                delegate: Rectangle {
                    id: star
                    required property int index
                    readonly property real s: 1 + (index * 7) % 3 * 0.6
                    width: s
                    height: s
                    radius: s / 2
                    color: "white"
                    x: ((index * 197 + 41) % 997) / 997 * afx.width
                    y: ((index * 131 + 7) % 991) / 991 * afx.height
                    opacity: 0.25
                    SequentialAnimation {
                        running: panel.running
                        loops: Animation.Infinite
                        PauseAnimation { duration: (star.index * 433) % 3000 }
                        OpacityAnimator { target: star; from: 0.15; to: 0.9; duration: 1400 + (star.index * 211) % 1600 }
                        OpacityAnimator { target: star; from: 0.9; to: 0.15; duration: 1600 + (star.index * 173) % 1800 }
                    }
                }
            }
        }
    }

    // retro perspective grid rolling toward you + a striped sun (vaporwave)
    Component {
        id: gridFx
        Item {
            id: g
            clip: true
            readonly property real horizon: height * 0.6
            property real phase: 0
            NumberAnimation on phase {
                running: panel.running
                from: 0; to: 1
                duration: 1800
                loops: Animation.Infinite
            }

            Item {
                id: sun
                width: Math.min(g.width * 0.42, 220)
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                y: g.horizon - height * 0.62
                opacity: 0.55
                layer.enabled: true
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(panel.th.warn, 1.15) }
                        GradientStop { position: 1.0; color: panel.th.accent }
                    }
                }
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        width: sun.width
                        height: 2 + index * 2
                        y: sun.height * (0.42 + index * 0.075)
                        color: panel.th.panelMid
                    }
                }
            }
            Rectangle {
                y: g.horizon
                width: parent.width
                height: parent.height - g.horizon
                color: Theme.alpha(panel.th.panelBottom, 0.85)
            }
            Rectangle {
                y: g.horizon - 14
                width: parent.width
                height: 28
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Theme.alpha(panel.th.accent, 0.35) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Theme.alpha(panel.th.accent2, 0.30)
                    strokeWidth: 1
                    fillColor: "transparent"
                    PathMultiline {
                        paths: {
                            const out = [], cx = g.width / 2;
                            for (let i = -9; i <= 9; i++)
                                out.push([Qt.point(cx + i * g.width * 0.025, g.horizon),
                                          Qt.point(cx + i * g.width * 0.14, g.height)]);
                            return out;
                        }
                    }
                }
            }
            Repeater {
                model: 9
                Rectangle {
                    required property int index
                    readonly property real k: (index + g.phase) / 9
                    width: g.width
                    height: 1
                    y: g.horizon + (g.height - g.horizon) * k * k
                    color: Theme.alpha(panel.th.accent2, 0.10 + 0.35 * k)
                }
            }
        }
    }

    // a slow phosphor beam rolling down the tube (phosphor)
    Component {
        id: beamFx
        Item {
            id: sc
            clip: true
            Rectangle {
                id: beam
                width: parent.width
                height: 90
                y: -height
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.6; color: Theme.alpha(panel.th.accent, 0.07) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                YAnimator on y {
                    running: panel.running
                    from: -beam.height
                    to: sc.height
                    duration: 6000
                    loops: Animation.Infinite
                }
            }
        }
    }

    // soft colour blobs drifting behind frosted glass (frost)
    Component {
        id: blobsFx
        Item {
            id: bl
            clip: true
            Repeater {
                model: [
                    { c: panel.th.accent,  x: 0.08, y: 0.10, r: 0.42, dx: 40, dy: 30, d: 17000 },
                    { c: panel.th.accent2, x: 0.62, y: 0.28, r: 0.50, dx: -50, dy: 24, d: 21000 },
                    { c: panel.th.warn,    x: 0.30, y: 0.70, r: 0.36, dx: 36, dy: -28, d: 19000 }
                ]
                delegate: Item {
                    id: blob
                    required property var modelData
                    readonly property real r: Math.min(bl.width, bl.height) * modelData.r
                    width: r
                    height: r
                    x: bl.width * modelData.x
                    y: bl.height * modelData.y
                    RectangularShadow {
                        id: glowBlob
                        width: blob.r                // not anchored: the animators move it
                        height: blob.r
                        radius: width / 2
                        blur: 70
                        color: Theme.alpha(blob.modelData.c, 0.30)
                    }
                    SequentialAnimation {
                        running: panel.running
                        loops: Animation.Infinite
                        ParallelAnimation {
                            XAnimator { target: glowBlob; from: 0; to: blob.modelData.dx; duration: blob.modelData.d; easing.type: Easing.InOutSine }
                            YAnimator { target: glowBlob; from: 0; to: blob.modelData.dy; duration: blob.modelData.d; easing.type: Easing.InOutSine }
                        }
                        ParallelAnimation {
                            XAnimator { target: glowBlob; from: blob.modelData.dx; to: 0; duration: blob.modelData.d; easing.type: Easing.InOutSine }
                            YAnimator { target: glowBlob; from: blob.modelData.dy; to: 0; duration: blob.modelData.d; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }
    }
}
