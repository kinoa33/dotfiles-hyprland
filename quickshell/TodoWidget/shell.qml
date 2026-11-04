// ╔══════════════════════════════════════════════════════════════╗
// ║  todo · themed overlay (quickshell)                          ║
// ║  toggle: Super+D (hypr/scripts/qs-toggle.sh TodoWidget)      ║
// ║                                                              ║
// ║  add     type + ⏎ ·  !  !!  !!!  priority                    ║
// ║          @today @tom @fri @+3 @+2w @10-24 @2026-10-24  due    ║
// ║  keys    ↑↓ select · ␣ done · ⏎ edit · del delete            ║
// ║          ^↑↓ move · ^P priority · ^F filter · ^Z undo        ║
// ║          esc  cancel edit › clear › deselect › close         ║
// ║  mouse   ring done · double-click edit · right-click priority║
// ║          hover ✕ delete · chips filter · footer clears done  ║
// ║  done tasks sink below the open ones; ^Z brings back any     ║
// ║  change (delete, clear, edit, tick…)                         ║
// ║  tabs: tasks · theme (ctrl+tab / alt+1,2)                    ║
// ║  tasks persist in QML LocalStorage through common/todo.js    ║
// ║  (the launcher's "+ task" row adds to the same list)         ║
// ║  ipc: add text · list · undo (quickshell ipc … call todo …)  ║
// ╚══════════════════════════════════════════════════════════════╝
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "common"
import "common/todo.js" as Todo

PanelWindow {
    id: root

    readonly property var th: Theme.t
    readonly property int margin: 44                    // shadow + pop-in room
    property string tab: "tasks"

    // sized to the panel, centred: the compositor only re-blurs this
    // patch when the glass animates. clicks elsewhere end the focus grab.
    implicitWidth: panel.width + margin * 2
    implicitHeight: panel.height + margin * 2
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-todo"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: Qt.quit()
    }

    property int editingIndex: -1
    property int sel: -1                                // selected row (keyboard)
    property string filter: "all"                       // all · open · today · done
    property int rev: 0                                 // bumps on every change (counts)
    property var undoStack: []
    property string toast: ""

    readonly property var filters: [
        { key: "all",   label: "all",   glyph: "\u{F0C9C}" },
        { key: "open",  label: "open",  glyph: "\u{F0130}" },
        { key: "today", label: "today", glyph: "\u{F00F6}" },
        { key: "done",  label: "done",  glyph: "\u{F0134}" }
    ]

    readonly property var counts: {
        void root.rev;
        const c = { all: 0, open: 0, today: 0, done: 0, late: 0 };
        const t = root.todayIso;
        for (let i = 0; i < tasksModel.count; i++) {
            const x = tasksModel.get(i);
            c.all++;
            if (x.done) { c.done++; continue; }
            c.open++;
            if (x.due && x.due <= t) c.today++;
            if (x.due && x.due < t) c.late++;
        }
        return c;
    }

    ListModel { id: tasksModel }

    // the store and the !! / @due syntax are shared with the launcher
    readonly property string todayIso: Todo.today()
    function prioColor(p) {
        return p >= 3 ? root.th.crit : p === 2 ? root.th.warn : root.th.accent;
    }

    function rows() {
        const out = [];
        for (let i = 0; i < tasksModel.count; i++) {
            const x = tasksModel.get(i);
            out.push({ title: x.title, done: x.done, prio: x.prio, due: x.due, created: x.created, doneAt: x.doneAt });
        }
        return out;
    }
    function saveTasks() {
        root.rev++;
        Todo.save(rows());
    }
    function loadTasks() {
        tasksModel.clear();
        for (const r of Todo.load()) tasksModel.append(r);
        root.rev++;
    }

    // ── undo · a snapshot before every change ────────────────────
    function snapshot() {
        root.undoStack = root.undoStack.concat([rows()]).slice(-40);
    }
    function undo() {
        if (!root.undoStack.length) { say("nothing to undo"); return; }
        const prev = root.undoStack[root.undoStack.length - 1];
        root.undoStack = root.undoStack.slice(0, -1);
        root.editingIndex = -1;
        tasksModel.clear();
        for (const r of prev) tasksModel.append(r);
        saveTasks();
        if (root.sel >= tasksModel.count) root.sel = tasksModel.count - 1;
        say("undone");
    }

    function say(msg) {
        root.toast = msg;
        toastTimer.restart();
    }
    Timer { id: toastTimer; interval: 3200; onTriggered: root.toast = "" }

    // ── changes ──────────────────────────────────────────────────
    function openCountExcept(i) {
        let n = 0;
        for (let k = 0; k < tasksModel.count; k++)
            if (k !== i && !tasksModel.get(k).done) n++;
        return n;
    }

    function addTask() {
        const e = Todo.parseEntry(taskInput.text);
        if (e.title === "") return;
        snapshot();
        // new tasks go to the end of the open ones, above the done block
        const at = Todo.insertAt(rows());
        tasksModel.insert(at, { title: e.title, done: false, prio: e.prio, due: e.due,
                                created: Date.now(), doneAt: 0 });
        saveTasks();
        taskInput.text = "";
        if (!passes(tasksModel.get(at))) root.filter = "all";        // don't add into thin air
        root.sel = -1;
        taskList.positionViewAtIndex(at, ListView.Contain);
    }

    // ticked tasks sink to the top of the done block; unticked ones
    // rise to the end of the open block
    function toggle(i) {
        if (i < 0 || i >= tasksModel.count) return;
        snapshot();
        const now = !tasksModel.get(i).done;
        tasksModel.setProperty(i, "done", now);
        tasksModel.setProperty(i, "doneAt", now ? Date.now() : 0);
        const to = openCountExcept(i);
        if (to !== i) tasksModel.move(i, to, 1);
        // the selection stays put, so ␣ ␣ ␣ ticks down the list
        if (root.sel === i) root.sel = nearest(i);
        saveTasks();
    }

    function removeAt(i) {
        if (i < 0 || i >= tasksModel.count) return;
        snapshot();
        const t = tasksModel.get(i).title;
        if (root.editingIndex === i) root.editingIndex = -1;
        tasksModel.remove(i);
        saveTasks();
        if (root.sel >= 0) root.sel = nearest(Math.min(i, tasksModel.count - 1));
        say("deleted “" + (t.length > 24 ? t.slice(0, 24) + "…" : t) + "”");
    }

    function clearDone() {
        if (!root.counts.done) return;
        snapshot();
        const n = root.counts.done;
        for (let i = tasksModel.count - 1; i >= 0; i--)
            if (tasksModel.get(i).done) tasksModel.remove(i);
        root.sel = -1;
        saveTasks();
        say("cleared " + n + " done");
    }

    function cyclePrio(i) {
        if (i < 0 || i >= tasksModel.count) return;
        snapshot();
        const p = (tasksModel.get(i).prio + 1) % 4;
        tasksModel.setProperty(i, "prio", p);
        saveTasks();
        say("priority · " + Todo.prioNames[p]);
    }

    function commitEdit(i, text) {
        const e = Todo.parseEntry(text);
        const x = tasksModel.get(i);
        root.editingIndex = -1;
        taskInput.forceActiveFocus();
        if (e.title === "" || (e.title === x.title && e.prio === x.prio && e.due === x.due)) return;
        snapshot();
        tasksModel.setProperty(i, "title", e.title);
        tasksModel.setProperty(i, "prio", e.prio);
        tasksModel.setProperty(i, "due", e.due);
        saveTasks();
    }

    function startEdit(i) {
        if (i < 0 || i >= tasksModel.count) return;
        root.sel = i;
        root.editingIndex = i;
    }

    // ── selection over the filtered rows ─────────────────────────
    function passes(x) {
        switch (root.filter) {
        case "open":  return !x.done;
        case "done":  return x.done;
        case "today": return !x.done && x.due !== "" && x.due <= root.todayIso;
        default:      return true;
        }
    }
    function nearest(i) {
        for (let k = i; k < tasksModel.count; k++) if (passes(tasksModel.get(k))) return k;
        for (let k = i - 1; k >= 0; k--) if (passes(tasksModel.get(k))) return k;
        return -1;
    }
    function step(from, d) {
        for (let k = from + d; k >= 0 && k < tasksModel.count; k += d)
            if (passes(tasksModel.get(k))) return k;
        return -1;
    }
    function moveSel(d) {
        if (!tasksModel.count) return;
        let n = root.sel < 0 ? (d > 0 ? step(-1, 1) : step(tasksModel.count, -1)) : step(root.sel, d);
        if (n < 0) n = root.sel < 0 ? -1 : root.sel;              // stay at the ends
        root.sel = n;
        if (n >= 0) taskList.positionViewAtIndex(n, ListView.Contain);
    }
    // ^↑↓: swap with the next visible neighbour
    function shift(d) {
        const i = root.sel;
        if (i < 0) return;
        const j = step(i, d);
        if (j < 0) return;
        snapshot();
        tasksModel.move(i, j, 1);
        root.sel = j;
        taskList.positionViewAtIndex(j, ListView.Contain);
        saveTasks();
    }
    function setFilter(f) {
        root.filter = f;
        root.editingIndex = -1;
        if (root.sel >= 0 && !passes(tasksModel.get(root.sel))) root.sel = -1;
    }
    function cycleFilter(d) {
        const keys = root.filters.map(f => f.key);
        setFilter(keys[(keys.indexOf(root.filter) + d + keys.length) % keys.length]);
    }

    function inputKey(ev) {
        const ctrl = ev.modifiers & Qt.ControlModifier;
        const empty = taskInput.text === "";
        let done = true;
        switch (ev.key) {
        case Qt.Key_Down:   ctrl ? shift(1) : moveSel(1); break;
        case Qt.Key_Up:     ctrl ? shift(-1) : moveSel(-1); break;
        case Qt.Key_PageDown: for (let k = 0; k < 6; k++) moveSel(1); break;
        case Qt.Key_PageUp:   for (let k = 0; k < 6; k++) moveSel(-1); break;
        case Qt.Key_Space:
            if (empty && root.sel >= 0) toggle(root.sel); else done = false;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (!empty) addTask();
            else if (root.sel >= 0) startEdit(root.sel);
            break;
        case Qt.Key_Delete:
            if ((empty || ev.modifiers & Qt.ShiftModifier) && root.sel >= 0) removeAt(root.sel); else done = false;
            break;
        case Qt.Key_P: if (ctrl) cyclePrio(root.sel); else done = false; break;
        case Qt.Key_F: if (ctrl) cycleFilter(ev.modifiers & Qt.ShiftModifier ? -1 : 1); else done = false; break;
        case Qt.Key_Z: if (ctrl) undo(); else done = false; break;
        default: done = false;
        }
        ev.accepted = done;
    }

    function back() {
        if (root.tab === "tasks") {
            if (root.editingIndex >= 0) { root.editingIndex = -1; taskInput.forceActiveFocus(); return; }
            if (taskInput.text !== "") { taskInput.text = ""; return; }
            if (root.sel >= 0) { root.sel = -1; return; }
        }
        Qt.quit();
    }

    function setTab(t) {
        root.tab = t;
        root.editingIndex = -1;
        if (t === "theme") picker.forceActiveFocus();
        else taskInput.forceActiveFocus();
    }

    Component.onCompleted: {
        Theme.widget = "todo";
        loadTasks();
    }

    // scripting it while it's open: `quickshell ipc -p ~/.config/quickshell/TodoWidget call todo add "…"`
    IpcHandler {
        target: "todo"
        function add(text: string): void { taskInput.text = text; root.addTask(); }
        function list(): string {
            return root.rows().map(x => (x.done ? "[x] " : "[ ] ") + Todo.entryText(x)).join("\n");
        }
        function undo(): void { root.undo(); }
        function filter(f: string): void { root.setFilter(f || "all"); }
    }

    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; onActivated: root.back() }
    Shortcut { sequence: "Ctrl+Tab"; context: Qt.ApplicationShortcut; onActivated: root.setTab(root.tab === "tasks" ? "theme" : "tasks") }
    Shortcut { sequence: "Alt+1"; context: Qt.ApplicationShortcut; onActivated: root.setTab("tasks") }
    Shortcut { sequence: "Alt+2"; context: Qt.ApplicationShortcut; onActivated: root.setTab("theme") }

    // clicks in the transparent margin close it
    MouseArea { anchors.fill: parent; onClicked: Qt.quit() }

    // ── the panel ────────────────────────────────────────────────
    ThemedPanel {
        id: panel
        title: "todo"
        x: root.margin
        y: root.margin
        width: 440
        height: 600

        // entry animation
        opacity: 0
        scale: 0.96
        Component.onCompleted: { opacity = 1; scale = 1; }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
        Behavior on scale   { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

        MouseArea { anchors.fill: parent }   // swallow clicks

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            anchors.topMargin: 18 + panel.topInset
            spacing: 12

            // ── header ───────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Emblem { glyph: root.tab === "theme" ? "󰏘" : "󰄲"; size: 38 }
                Text {
                    text: root.tab === "theme" ? "theme" : "todo"
                    color: root.th.text
                    font { family: root.th.font; pixelSize: 19; bold: true }
                }
                Item { Layout.fillWidth: true }
                Item {
                    visible: root.tab === "tasks"
                    implicitWidth: countText.implicitWidth + 18
                    implicitHeight: 22
                    Surface { anchors.fill: parent; radius: root.th.pillFull ? 11 : root.th.radiusSm; strength: 0.45 }
                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: root.counts.open + " open" + (root.counts.late ? "  ·  " + root.counts.late + " late" : "")
                        color: root.th.text
                        font { family: root.th.font; pixelSize: 12 }
                    }
                }
            }

            TabBar {
                model: [
                    { key: "tasks", label: "tasks", glyph: "󰝖" },
                    { key: "theme", label: "theme", glyph: "󰏘" }
                ]
                current: root.tab
                onPicked: (key) => root.setTab(key)
            }

            // ── input · with a live read of !! and @due ──────────
            Field {
                id: inField
                visible: root.tab === "tasks"
                Layout.fillWidth: true
                implicitHeight: 40
                focused: taskInput.activeFocus

                readonly property var entry: Todo.parseEntry(taskInput.text)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 1
                    anchors.rightMargin: 12
                    spacing: 8

                    TextField {
                        id: taskInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        leftPadding: 14
                        rightPadding: 4
                        placeholderText: "new task  ·  !! priority  ·  @fri due"
                        placeholderTextColor: root.th.faint
                        color: root.th.text
                        selectionColor: Theme.alpha(root.th.accent, 0.45)
                        selectedTextColor: root.th.selText
                        font { family: root.th.font; pixelSize: 14 }
                        background: null
                        focus: true
                        Keys.onPressed: (ev) => root.inputKey(ev)
                    }
                    Text {                                    // what the tokens mean
                        visible: inField.entry.prio > 0
                        text: "!".repeat(inField.entry.prio) + " " + Todo.prioNames[inField.entry.prio]
                        color: inField.entry.prio >= 3 ? root.th.critInk : inField.entry.prio === 2 ? root.th.warnInk : root.th.ink
                        font { family: root.th.font; pixelSize: 11; bold: true }
                    }
                    Text {
                        visible: inField.entry.due !== ""
                        text: "\u{F00ED}  " + Todo.dueLabel(inField.entry.due)
                        color: root.th.dim
                        font { family: root.th.font; pixelSize: 11 }
                    }
                }
            }

            // ── filter chips ─────────────────────────────────────
            Row {
                visible: root.tab === "tasks"
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: root.filters
                    delegate: Item {
                        id: chip
                        required property var modelData
                        readonly property bool active: root.filter === modelData.key
                        readonly property int n: root.counts[modelData.key]
                        implicitWidth: chipRow.implicitWidth + 20
                        implicitHeight: 24
                        Surface {
                            anchors.fill: parent
                            radius: root.th.pillFull ? height / 2 : root.th.radiusSm
                            tint: chip.active ? root.th.accent : root.th.text
                            strength: chip.active ? 1 : (chipHover.hovered ? 0.4 : 0.15)
                        }
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.glyph
                                color: chip.active ? root.th.selText
                                     : chip.modelData.key === "today" && root.counts.late ? root.th.critInk : root.th.dim
                                font { family: root.th.glyphFont; pixelSize: 12 }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.label + "  " + chip.n
                                color: chip.active ? root.th.selText : root.th.dim
                                font { family: root.th.font; pixelSize: 11 }
                            }
                        }
                        HoverHandler { id: chipHover }
                        TapHandler { onTapped: { root.setFilter(chip.modelData.key); taskInput.forceActiveFocus(); } }
                    }
                }
            }

            // ── task list ────────────────────────────────────────
            ListView {
                id: taskList
                visible: root.tab === "tasks"
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: tasksModel
                clip: true
                spacing: 0                                  // rows carry their own gap (filtered rows are 0 high)
                boundsBehavior: Flickable.StopAtBounds

                // rows glide in and out instead of popping
                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutQuint }
                    NumberAnimation { property: "scale"; from: 0.92; to: 1; duration: 220; easing.type: Easing.OutQuint }
                }
                remove: Transition {
                    NumberAnimation { property: "opacity"; to: 0; duration: 140 }
                    NumberAnimation { property: "scale"; to: 0.92; duration: 140 }
                }
                displaced: Transition {
                    NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutQuint }
                }
                move: Transition {
                    NumberAnimation { property: "y"; duration: 240; easing.type: Easing.OutQuint }
                }

                delegate: Item {
                    id: row
                    required property int index
                    required property string title
                    required property bool done
                    required property int prio
                    required property string due
                    readonly property bool shown: root.rev >= 0 && root.passes({ done: done, due: due })
                    readonly property bool editing: index >= 0 && root.editingIndex === index
                    readonly property bool lit: index >= 0 && root.sel === index && !editing
                    readonly property int late: due ? Todo.daysUntil(due) : 1
                    width: taskList.width
                    height: shown ? 46 : 0
                    visible: shown

                    HoverHandler { id: rowHover }

                    Item {
                        anchors.fill: parent
                        anchors.bottomMargin: 4

                        Surface {
                            anchors.fill: parent
                            strength: row.lit ? 1 : row.editing ? 0.5 : rowHover.hovered ? 0.35 : 0
                            tint: root.th.accent
                            tick: row.lit
                        }

                        Rectangle {                         // priority strip
                            visible: row.prio > 0
                            x: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: parent.height * 0.56
                            radius: 1.5
                            color: root.prioColor(row.prio)
                            opacity: row.done ? 0.35 : 1
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            enabled: !row.editing
                            onClicked: (m) => {
                                root.sel = row.index;
                                if (m.button === Qt.RightButton) root.cyclePrio(row.index);
                                taskInput.forceActiveFocus();
                            }
                            onDoubleClicked: (m) => { if (m.button === Qt.LeftButton) root.startEdit(row.index); }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            spacing: 10

                            // done ring
                            Item {
                                implicitWidth: 20
                                implicitHeight: 20
                                Surface {
                                    anchors.fill: parent
                                    visible: row.done
                                    radius: root.th.surface === "block" ? 2 : 10
                                    tint: row.lit ? root.th.selText : root.th.accent
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    visible: !row.done
                                    radius: root.th.surface === "block" ? 2 : 10
                                    color: "transparent"
                                    border.width: 2
                                    border.color: row.lit ? Theme.alpha(root.th.selText, 0.7)
                                                : row.prio ? Theme.alpha(root.prioColor(row.prio), 0.8)
                                                : Theme.alpha(root.th.text, 0.35)
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: row.done
                                    text: "󰄬"
                                    color: row.lit ? root.th.accent : root.th.selText
                                    font { family: root.th.glyphFont; pixelSize: 12 }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    onClicked: { root.toggle(row.index); taskInput.forceActiveFocus(); }
                                }
                            }

                            // title / inline editor
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    visible: !row.editing
                                    text: row.title
                                    elide: Text.ElideRight
                                    color: row.lit ? (row.done ? root.th.selDim : root.th.selText)
                                         : row.done ? root.th.faint : root.th.text
                                    font { family: root.th.font; pixelSize: 14; strikeout: row.done }
                                }
                                Loader {                    // only the row being edited has an editor
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    active: row.editing
                                    sourceComponent: TextField {
                                        color: root.th.text
                                        selectionColor: Theme.alpha(root.th.accent, 0.45)
                                        selectedTextColor: root.th.selText
                                        font { family: root.th.font; pixelSize: 14 }
                                        leftPadding: 0
                                        background: Item {
                                            Rectangle {   // underline
                                                anchors.bottom: parent.bottom
                                                width: parent.width; height: 1
                                                color: Theme.alpha(root.th.accent, 0.7)
                                            }
                                        }
                                        Component.onCompleted: {
                                            text = Todo.entryText(tasksModel.get(row.index));
                                            forceActiveFocus();
                                            select(0, Todo.entryText({ title: row.title, prio: 0, due: "" }).length);
                                        }
                                        onAccepted: root.commitEdit(row.index, text)
                                        onActiveFocusChanged: if (!activeFocus && root.editingIndex === row.index) root.editingIndex = -1
                                    }
                                }
                            }

                            // due
                            Text {
                                visible: row.due !== "" && !row.editing
                                text: "\u{F00ED}  " + Todo.dueLabel(row.due)
                                color: row.lit ? root.th.selDim
                                     : row.done ? root.th.faint
                                     : row.late < 0 ? root.th.critInk
                                     : row.late === 0 ? root.th.warnInk : root.th.dim
                                font { family: root.th.font; pixelSize: 11; bold: !row.done && row.late <= 0 }
                            }

                            // delete
                            Text {
                                text: "󰅖"
                                visible: rowHover.hovered && !row.editing
                                color: row.lit ? Theme.alpha(root.th.selText, delHover.hovered ? 1 : 0.7)
                                               : Theme.alpha(root.th.critInk, delHover.hovered ? 1.0 : 0.75)
                                font { family: root.th.glyphFont; pixelSize: 13 }
                                HoverHandler { id: delHover }
                                TapHandler { onTapped: root.removeAt(row.index) }
                            }
                        }
                    }
                }

                // empty states
                Text {
                    anchors.centerIn: parent
                    readonly property int n: root.counts[root.filter]
                    visible: n === 0
                    text: tasksModel.count === 0 ? "nothing here · type above"
                        : root.filter === "today" ? "nothing due today"
                        : root.filter === "open" ? "all done 󰄬"
                        : root.filter === "done" ? "nothing ticked off yet" : ""
                    color: root.th.faint
                    font { family: root.th.font; pixelSize: 13; italic: true }
                }
            }

            // ── theme tab ────────────────────────────────────────
            ThemePicker {
                id: picker
                visible: root.tab === "theme"
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // ── progress ─────────────────────────────────────────
            Rectangle {
                visible: root.tab === "tasks" && root.counts.all > 0
                Layout.fillWidth: true
                implicitHeight: 3
                radius: 1.5
                color: Theme.alpha(root.th.text, 0.08)
                Rectangle {
                    width: parent.width * (root.counts.all ? root.counts.done / root.counts.all : 0)
                    height: parent.height
                    radius: 1.5
                    color: root.th.accent
                    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                }
            }

            // ── footer ───────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                readonly property bool tasks: root.tab === "tasks"
                readonly property bool picked: tasks && root.sel >= 0 && root.editingIndex < 0

                Text {
                    visible: parent.tasks && root.toast !== ""
                    text: root.toast
                    color: root.th.dim
                    font { family: root.th.font; pixelSize: 12; italic: true }
                }
                Text {
                    visible: parent.tasks && root.toast === "" && !parent.picked
                    text: root.counts.done + " of " + root.counts.all + " done"
                    color: root.th.faint
                    font { family: root.th.font; pixelSize: 12 }
                }
                Text {
                    text: "clear done"
                    visible: parent.tasks && root.toast === "" && !parent.picked && root.counts.done > 0
                    color: clearHover.hovered ? root.th.critInk : Theme.alpha(root.th.critInk, 0.8)
                    font { family: root.th.font; pixelSize: 12 }
                    HoverHandler { id: clearHover }
                    TapHandler { onTapped: root.clearDone() }
                }
                Keycap { visible: parent.picked && root.toast === ""; keys: "␣"; label: "done" }
                Keycap { visible: parent.picked && root.toast === ""; keys: "⏎"; label: "edit" }
                Keycap { visible: parent.picked && root.toast === ""; keys: "^↑↓"; label: "move" }
                Keycap { visible: parent.picked && root.toast === ""; keys: "^P"; label: "priority" }
                Keycap { visible: parent.tasks && root.editingIndex >= 0; keys: "⏎"; label: "save" }
                Keycap { visible: parent.tasks && root.editingIndex >= 0; keys: "!! @fri"; label: "priority · due" }
                Keycap { visible: parent.tasks && root.toast !== "" && root.undoStack.length > 0; keys: "^Z"; label: "undo" }
                Keycap { visible: root.tab === "theme"; keys: "⏎"; label: "apply" }
                Keycap { visible: root.tab === "theme"; keys: "L"; label: "link" }
                Keycap { visible: root.tab === "theme"; keys: "E"; label: "studio" }
                Item { Layout.fillWidth: true }
                Keycap { visible: !parent.picked; keys: "^tab"; label: "tabs" }
                Keycap { keys: "esc"; label: parent.tasks && (root.editingIndex >= 0 || root.sel >= 0) ? "back" : "close" }
            }
        }
    }
}
