// the theme tab every widget carries.
//   for       which widget you're theming — starts on the host, but any
//             tab can theme any widget (waybar has no qml of its own,
//             so its theme lives here too)
//   cards     one per aesthetic, each with a live miniature
//   linked    on: picking re-themes every linked widget
//             off: the target keeps its own theme
//   motion    bubbles / grid / petals … on or off, everywhere
//   studio    open the theme studio on the highlighted theme, to change
//             it (for every widget, or just this one) or make a new one
// keys (when focused, or forwarded via handleKey):
//   ←→↑↓ choose   ⏎/space apply   L link   M motion   T next target
//   C next category   E studio
import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

FocusScope {
    id: picker
    property var th: Theme.t
    property string target: Theme.widget
    property int index: 0
    property string cat: ""                  // "" all · glass · retro · console · mood
    property string query: ""                // hosts with a search field filter by it
    // searchable words per theme (light/dark included), rebuilt only when the palette moves
    readonly property var words: {
        const m = {};
        for (const x of Theme.themes)
            m[x.id] = (x.id + " " + x.label + " " + x.blurb + " " + x.cat + (Theme.tokens(x.id).dark ? " dark" : " light")
                       + (x.custom ? " mine yours custom" : x.modified ? " mine changed modified" : "")).toLowerCase();
        return m;
    }
    readonly property var list: {
        const q = query.toLowerCase().split(/\s+/).filter(w => w);
        return Theme.themes.filter(x => Theme.inCat(x, cat) && q.every(w => words[x.id].indexOf(w) >= 0));
    }
    // typing never re-themes the panel; arrowing through the cards does
    onQueryChanged: { index = 0; endPreview(); }
    property string keyPrefix: ""            // "^" where the host's letters type into a search
    readonly property int count: list.length
    readonly property int columns: width >= 540 ? 2 : 1
    readonly property bool linked: Theme.isLinked(target)
    readonly property string wearing: Theme.effectiveFor(target)

    // try the highlighted look on this very widget (not saved until ⏎)
    function tryOn() {
        Theme.previewId = target === Theme.widget && list[index] ? list[index].id : "";
    }
    function endPreview() { Theme.previewId = ""; }

    function sync() {
        // read the theme straight from Theme: when `target` has just changed,
        // the `wearing` binding may not have caught up yet
        const id = Theme.effectiveFor(target);
        if (!list.some(x => x.id === id)) cat = "";               // show the one it wears
        index = Math.max(0, list.findIndex(x => x.id === id));
        Qt.callLater(() => grid.positionViewAtIndex(index, GridView.Contain));
    }
    function reset() {                       // back to theming the host widget
        target = Theme.widget;
        sync();
    }
    Component.onCompleted: sync()
    onVisibleChanged: visible ? sync() : endPreview()
    onTargetChanged: { endPreview(); sync(); }

    function show(i) {
        index = i;
        grid.positionViewAtIndex(i, GridView.Contain);
        tryOn();
    }
    function move(d) { show((index + d + count) % count); }
    function moveRow(d) {
        const i = index + d * columns;
        if (i >= 0 && i < count) show(i);
    }
    function apply() {
        if (!list[index]) return;
        Theme.pickFor(target, list[index].id);
        endPreview();
    }
    function nextCat(d) {
        const keys = Theme.cats.map(c => c.key);
        cat = keys[(keys.indexOf(cat) + (d || 1) + keys.length) % keys.length];
        index = 0;
        grid.positionViewAtBeginning();
    }
    function toggleLink() {
        endPreview();                        // show what it really wears now
        Theme.setLinkedFor(target, !linked);
        Qt.callLater(sync);                  // and land on that card
    }
    function toggleMotion() { Theme.setMotion(!Theme.motion); }
    // the studio, on the highlighted theme, previewing the target widget
    function openStudio() {
        endPreview();
        const id = list[index] ? list[index].id : wearing;
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/theme-studio.sh", id, target]);
    }
    function nextTarget(d) {
        const keys = Theme.widgets.map(w => w.key);
        target = keys[(keys.indexOf(target) + (d || 1) + keys.length) % keys.length];
    }

    // hosts that keep keyboard focus elsewhere forward keys here
    function handleKey(ev) {
        switch (ev.key) {
        case Qt.Key_Left:   move(-1); return true;
        case Qt.Key_Right:  move(1); return true;
        case Qt.Key_Up:     moveRow(-1); return true;
        case Qt.Key_Down:   moveRow(1); return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:  apply(); return true;
        case Qt.Key_L:      toggleLink(); return true;
        case Qt.Key_M:      toggleMotion(); return true;
        case Qt.Key_T:      nextTarget(ev.modifiers & Qt.ShiftModifier ? -1 : 1); return true;
        case Qt.Key_C:      nextCat(ev.modifiers & Qt.ShiftModifier ? -1 : 1); return true;
        case Qt.Key_E:      openStudio(); return true;
        }
        return false;
    }
    Keys.onPressed: (ev) => { ev.accepted = picker.handleKey(ev); }

    readonly property string linkedNames: Theme.widgets.filter(w => Theme.isLinked(w.key))
                                                       .map(w => w.label).join(" · ")

    // ── a pill switch ────────────────────────────────────────────
    component Switch: Item {
        id: sw
        property string glyph
        property string label
        property string key
        property bool on
        signal toggled()
        implicitWidth: swRow.implicitWidth + 24
        implicitHeight: 30

        Surface {
            anchors.fill: parent
            th: picker.th
            radius: picker.th.pillFull ? height / 2 : picker.th.radiusSm
            tint: sw.on ? picker.th.accent : picker.th.text
            strength: sw.on ? 1 : (swHover.hovered ? 0.4 : 0.22)
        }
        Row {
            id: swRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sw.glyph
                color: sw.on ? picker.th.selText : picker.th.dim
                font { family: picker.th.glyphFont; pixelSize: 15 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sw.label
                color: sw.on ? picker.th.selText : picker.th.dim
                font { family: picker.th.font; pixelSize: 12 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sw.key
                color: sw.on ? picker.th.selDim : picker.th.faint
                font { family: picker.th.font; pixelSize: 10 }
            }
        }
        HoverHandler { id: swHover }
        TapHandler { onTapped: sw.toggled() }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ── which widget ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            Text {
                text: "for"
                color: picker.th.faint
                font { family: picker.th.font; pixelSize: 11 }
            }
            Repeater {
                model: Theme.widgets
                delegate: Item {
                    id: tgt
                    required property var modelData
                    readonly property bool active: picker.target === modelData.key
                    // labels on every chip only when all of them fit; else just the target's
                    readonly property bool wide: picker.width >= 110 * Theme.widgets.length || active
                    implicitWidth: tgtRow.implicitWidth + 18
                    implicitHeight: 26
                    Surface {
                        anchors.fill: parent
                        th: picker.th
                        radius: picker.th.pillFull ? height / 2 : picker.th.radiusSm
                        tint: tgt.active ? picker.th.accent : picker.th.text
                        strength: tgt.active ? 1 : (tgtHover.hovered ? 0.35 : 0.12)
                    }
                    Row {
                        id: tgtRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tgt.modelData.glyph
                            color: tgt.active ? picker.th.selText : picker.th.dim
                            font { family: picker.th.glyphFont; pixelSize: 13 }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: tgt.wide
                            text: tgt.modelData.label
                            color: tgt.active ? picker.th.selText : picker.th.dim
                            font { family: picker.th.font; pixelSize: 11 }
                        }
                    }
                    HoverHandler { id: tgtHover }
                    TapHandler { onTapped: picker.target = tgt.modelData.key }
                }
            }
            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Switch {
                glyph: on ? "󰌹" : "󰌺"
                label: on ? "linked" : "own theme"
                key: picker.keyPrefix + "L"
                on: picker.linked
                onToggled: picker.toggleLink()
            }
            Switch {
                glyph: on ? "󰗘" : "󱖒"
                label: on ? "motion" : "still"
                key: picker.keyPrefix + "M"
                on: Theme.motion
                onToggled: picker.toggleMotion()
            }
            Switch {                                // change this theme / make one
                glyph: "\u{F03EB}"
                label: "studio"
                key: picker.keyPrefix + "E"
                on: false
                onToggled: picker.openStudio()
            }
            Switch {                                // a sample, to judge the look
                visible: picker.target === "notifications"
                glyph: "󰂚"
                label: "test"
                key: ""
                on: false
                onToggled: Quickshell.execDetached(["sh", "-c",
                    'notify-send -a theme -i preferences-desktop-theme -h int:value:64 ' +
                    '-h string:x-dunst-stack-tag:theme-test "notifications · $1" "how this theme looks — with a progress bar"',
                    "test", Theme.labelOf(picker.wearing)])
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: picker.linked
                    ? "linked: " + picker.linkedNames
                    : Theme.widgetLabel(picker.target) + " keeps its own · linked widgets wear " + Theme.labelOf(Theme.state.shared)
                color: picker.th.faint
                font { family: picker.th.font; pixelSize: 10 }
            }
        }

        // ── categories ───────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            Repeater {
                model: Theme.cats
                delegate: Item {
                    id: catChip
                    required property var modelData
                    readonly property bool active: picker.cat === modelData.key
                    readonly property int n: Theme.themes.filter(x => Theme.inCat(x, modelData.key)).length
                    visible: n > 0 || active
                    implicitWidth: catText.implicitWidth + 18
                    implicitHeight: 24
                    Surface {
                        anchors.fill: parent
                        th: picker.th
                        radius: picker.th.pillFull ? height / 2 : picker.th.radiusSm
                        tint: catChip.active ? picker.th.accent : picker.th.text
                        strength: catChip.active ? 1 : (catHover.hovered ? 0.35 : 0.12)
                    }
                    Text {
                        id: catText
                        anchors.centerIn: parent
                        text: catChip.modelData.label + " " + catChip.n
                        color: catChip.active ? picker.th.selText : picker.th.dim
                        font { family: picker.th.font; pixelSize: 11 }
                    }
                    HoverHandler { id: catHover }
                    TapHandler { onTapped: { picker.cat = catChip.modelData.key; picker.index = 0; grid.positionViewAtBeginning(); } }
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: picker.keyPrefix + "C"
                color: picker.th.faint
                font { family: picker.th.font; pixelSize: 10 }
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: Math.floor(width / picker.columns)
            cellHeight: 112
            model: picker.list
            boundsBehavior: Flickable.StopAtBounds

            Text {
                anchors.centerIn: parent
                visible: picker.list.length === 0
                text: "no theme matches “" + picker.query + "”"
                color: picker.th.faint
                font { family: picker.th.font; pixelSize: 13; italic: true }
            }

            delegate: Item {
                id: card
                required property var modelData
                required property int index
                readonly property var pt: Theme.tokens(modelData.id, picker.target)
                readonly property bool sel: picker.index === index
                readonly property bool inUse: picker.wearing === modelData.id
                width: grid.cellWidth
                height: grid.cellHeight

                Surface {
                    anchors.fill: parent
                    anchors.margins: 4
                    th: picker.th
                    radius: picker.th.bevel ? 0 : picker.th.radiusSm + 2
                    strength: card.sel ? 1 : (cardHover.hovered ? 0.35 : 0)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    // ── a miniature of the theme ─────────────────
                    Rectangle {
                        id: mini
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 76
                        radius: Math.min(10, card.pt.radius * 0.55)
                        clip: true
                        gradient: Gradient {
                            GradientStop { position: 0.0;  color: card.pt.panelTop }
                            GradientStop { position: 0.3;  color: card.pt.panelMid }
                            GradientStop { position: 1.0;  color: card.pt.panelBottom }
                        }
                        border.width: 1
                        border.color: card.pt.bevel ? card.pt.shade : card.pt.panelBorder

                        // fx hints
                        Image {                                     // rice: the wallpaper band
                            visible: card.pt.fx === "banner"
                            width: parent.width; height: 34
                            source: visible && WalColors.wallpaper ? "file://" + WalColors.wallpaper : ""
                            sourceSize.width: 240
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: 0.55
                        }
                        Rectangle {                                 // classic: title bar
                            visible: card.pt.fx === "titlebar"
                            x: 2; y: 2; width: parent.width - 4; height: 9
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: card.pt.titleStyle === "luna" ? card.pt.xp : card.pt.accent }
                                GradientStop { position: 1.0; color: card.pt.titleStyle === "luna" ? Qt.lighter(card.pt.xp, 1.3) : card.pt.accent2 }
                            }
                        }
                        Repeater {                                  // aero bubbles
                            model: card.pt.fx === "bubbles" ? 4 : 0
                            Rectangle {
                                required property int index
                                width: 5 + index * 2; height: width; radius: width / 2
                                x: 68 + index * 10; y: 62 - index * 9
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.55)
                            }
                        }
                        Repeater {                                  // sakura petals
                            model: card.pt.fx === "petals" ? 5 : 0
                            Rectangle {
                                required property int index
                                width: 6; height: 4; radius: 2
                                rotation: index * 35
                                x: 64 + (index * 13) % 40; y: 30 + index * 8
                                color: card.pt.accent
                            }
                        }
                        Repeater {                                  // aurora stars
                            model: card.pt.fx === "aurora" ? 9 : 0
                            Rectangle {
                                required property int index
                                width: 2; height: 2; radius: 1
                                x: (index * 37) % 104 + 4; y: (index * 23) % 30 + 4
                                color: "white"
                                opacity: 0.4 + (index % 3) * 0.2
                            }
                        }
                        Rectangle {                                 // aurora curtain
                            visible: card.pt.fx === "aurora"
                            x: 10; y: 8; width: 90; height: 12; radius: 6
                            color: Theme.alpha(card.pt.accent, 0.25)
                        }
                        Repeater {                                  // vapor grid
                            model: card.pt.fx === "grid" ? 4 : 0
                            Rectangle {
                                required property int index
                                width: parent.width; height: 1
                                y: 54 + index * index * 2 + index * 2
                                color: Theme.alpha(card.pt.accent2, 0.5)
                            }
                        }
                        Repeater {                                  // phosphor scanlines
                            model: card.pt.fx === "scanlines" ? 26 : 0
                            Rectangle {
                                required property int index
                                width: parent.width; height: 1; y: index * 3
                                color: Qt.rgba(0, 0, 0, 0.3)
                            }
                        }
                        Rectangle {                                 // sweep: a diagonal shine
                            visible: card.pt.fx === "sweep"
                            x: 60; y: -20; width: 16; height: 120; rotation: 22
                            color: card.pt.dark ? Qt.rgba(1, 1, 1, 0.12) : Theme.alpha(card.pt.accent, 0.25)
                        }
                        Repeater {                                  // eco: sunbeams
                            model: card.pt.fx === "eco" ? 3 : 0
                            Rectangle {
                                required property int index
                                x: index * 14 - 6; y: -10; width: 10; height: 90
                                rotation: -30 + index * 9; transformOrigin: Item.Top
                                color: Qt.rgba(1, 1, 0.9, 0.35 - index * 0.08)
                            }
                        }
                        Repeater {                                  // wii / game boy: stripes, lcd
                            model: card.pt.fx === "wii" || card.pt.fx === "dmg" ? 19 : 0
                            Rectangle {
                                required property int index
                                width: parent.width; height: 1; y: index * 4 + 2
                                color: card.pt.fx === "dmg" ? Qt.rgba(0.06, 0.22, 0.06, 0.12) : Qt.rgba(0, 0, 0, 0.05)
                            }
                        }
                        Text {                                      // steins;gate: the meter
                            visible: card.pt.fx === "divergence"
                            anchors.right: parent.right; anchors.rightMargin: 4; y: 52
                            text: "1.048596"
                            color: Theme.alpha(card.pt.accent, 0.55)
                            font { family: card.pt.font; pixelSize: 11 }
                        }
                        Rectangle {                                 // ps3: the wave
                            visible: card.pt.fx === "wave"
                            x: -10; y: 52; width: parent.width + 20; height: 9; radius: 4; rotation: -6
                            color: Qt.rgba(1, 1, 1, 0.22)
                        }
                        Rectangle {                                 // xbox: the ring
                            visible: card.pt.fx === "xbox"
                            x: 78; y: 44; width: 26; height: 26; radius: 13
                            color: "transparent"; border.width: 3; border.color: Theme.alpha(card.pt.accent, 0.6)
                        }
                        Rectangle {                                 // persona: a slash
                            visible: card.pt.fx === "p5"
                            x: 84; y: -10; width: 8; height: 100; rotation: 28
                            color: Theme.alpha(card.pt.accent, 0.5)
                        }
                        Rectangle {                                 // frost blob
                            visible: card.pt.fx === "blobs"
                            x: 64; y: 38; width: 42; height: 42; radius: 21
                            color: Theme.alpha(card.pt.accent, 0.25)
                        }

                        readonly property int topY: card.pt.fx === "titlebar" ? 14 : 7
                        Rectangle {                                 // emblem
                            x: 7; y: mini.topY; width: 14; height: 14
                            radius: card.pt.emblem === "prompt" || card.pt.bevel ? 2 : card.pt.emblem === "soft" || card.pt.emblem === "plain" ? 4 : 7
                            color: card.pt.emblem === "plain" ? "transparent" : card.pt.accent
                            border.width: card.pt.emblem === "prompt" || card.pt.emblem === "plain" || card.pt.emblem === "lens" ? 1 : 0
                            border.color: card.pt.emblem === "plain" ? card.pt.dim : Qt.lighter(card.pt.accent, 1.3)
                        }
                        Rectangle {                                 // search field
                            x: 26; y: mini.topY + 1; width: parent.width - 33; height: 12
                            radius: card.pt.pillFull ? 6 : Math.min(4, card.pt.radiusSm)
                            color: card.pt.field
                            border.width: 1
                            border.color: card.pt.bevel ? card.pt.shade : card.pt.fieldBorder
                        }
                        Surface {                                   // selected row
                            th: card.pt
                            x: 7; y: mini.topY + 21; width: parent.width - 14; height: 15
                            radius: Math.min(5, card.pt.radiusSm)
                        }
                        Rectangle { x: 13; y: mini.topY + 27; width: 46; height: 3; radius: 1.5; color: card.pt.selText }
                        Repeater {                                  // plain rows
                            model: 2
                            Rectangle {
                                required property int index
                                x: 13; y: mini.topY + 44 + index * 11
                                width: 54 - index * 16; height: 3; radius: 1.5
                                color: card.pt.dim
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7
                            Text {
                                text: card.modelData.glyph
                                color: card.sel ? picker.th.selText : picker.th.ink
                                font { family: picker.th.glyphFont; pixelSize: 15 }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: card.modelData.label
                                elide: Text.ElideRight
                                color: card.sel ? picker.th.selText : picker.th.text
                                font { family: picker.th.font; pixelSize: 14; bold: card.sel }
                            }
                            Text {                          // yours / changed in the studio
                                visible: card.modelData.custom || card.modelData.modified
                                text: card.modelData.custom ? "yours" : "changed"
                                color: card.sel ? picker.th.selDim : picker.th.faint
                                font { family: picker.th.font; pixelSize: 10; italic: true }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.blurb
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            color: card.sel ? picker.th.selDim : picker.th.dim
                            font { family: picker.th.font; pixelSize: 11 }
                        }
                        Text {
                            visible: card.inUse || Theme.previewId === card.modelData.id
                            text: card.inUse ? "󰄬  " + Theme.widgetLabel(picker.target) + " wears it"
                                             : "󰛐  trying on · ⏎ keep"
                            color: card.sel ? picker.th.selText : picker.th.ink
                            font { family: picker.th.font; pixelSize: 11 }
                        }
                    }
                }

                HoverHandler { id: cardHover }
                TapHandler {
                    onTapped: {
                        picker.show(card.index);
                        picker.apply();
                    }
                }
            }
        }
    }
}
