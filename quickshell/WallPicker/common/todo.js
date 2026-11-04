// the to-do list's store and quick-add syntax, shared by TodoWidget
// and the launcher's "+ task" row.
//
//   tasks live in QML LocalStorage: db "todoDB", table tasks
//   (text, done, prio, due, created, done_at), in list order.
//   every quickshell config opens the same file
//   (~/.local/share/quickshell/QML/OfflineStorage).
//
//   quick-add: words are the title, plus
//     !  !!  !!!                        priority low · medium · high
//     @today @tom @fri @+3 @+2w @week   due, relative
//     @10-24  @2026-10-24               due, a date
.pragma library
.import QtQuick.LocalStorage as Sql

var dayNames = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
var monthNames = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
var prioNames = ["none", "low", "medium", "high"];

// ── dates (local time, yyyy-mm-dd) ───────────────────────────────
function pad(n) { return (n < 10 ? "0" : "") + n; }
function iso(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); }
function fromIso(s) { var p = s.split("-").map(Number); return new Date(p[0], p[1] - 1, p[2]); }
function today() { return iso(new Date()); }
function addDays(n) { var d = new Date(); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() + n); return iso(d); }
function daysUntil(s) { var d = new Date(); d.setHours(0, 0, 0, 0); return Math.round((fromIso(s) - d) / 864e5); }

// "fri" / "+3" / "10-24" … → yyyy-mm-dd, or "" when it isn't a date
function parseDue(w) {
    w = w.toLowerCase();
    if (w === "today" || w === "tod") return addDays(0);
    if (w === "tomorrow" || w === "tom" || w === "tmr") return addDays(1);
    if (w === "week" || w === "nextweek") return addDays(7);
    var m = w.match(/^\+(\d{1,3})([dw]?)$/);
    if (m) return addDays(Number(m[1]) * (m[2] === "w" ? 7 : 1));
    var wd = dayNames.findIndex(function(n) {
        return w === n || (n === w.slice(0, 3) && /^[a-z]+day$/.test(w));
    });
    if (wd >= 0) return addDays((wd - new Date().getDay() + 7) % 7);
    m = w.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
    if (m && Number(m[2]) >= 1 && Number(m[2]) <= 12 && Number(m[3]) >= 1 && Number(m[3]) <= 31)
        return iso(new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3])));
    m = w.match(/^(\d{1,2})-(\d{1,2})$/);
    if (m && Number(m[1]) >= 1 && Number(m[1]) <= 12 && Number(m[2]) >= 1 && Number(m[2]) <= 31) {
        var d = new Date(new Date().getFullYear(), Number(m[1]) - 1, Number(m[2]));
        if (iso(d) < addDays(-60)) d.setFullYear(d.getFullYear() + 1);    // "@1-5" in october: next january
        return iso(d);
    }
    return "";
}

// what you type → { title, prio, due }
function parseEntry(text) {
    var keep = [], prio = 0, due = "";
    var words = String(text).trim().split(/\s+/);
    for (var i = 0; i < words.length; i++) {
        var w = words[i];
        if (/^!{1,3}$/.test(w)) { prio = w.length; continue; }
        if (w.length > 1 && w[0] === "@") {
            var d = parseDue(w.slice(1));
            if (d) { due = d; continue; }
        }
        if (w) keep.push(w);
    }
    return { title: keep.join(" "), prio: prio, due: due };
}

// …and back, for an editor
function entryText(x) {
    return x.title + (x.prio ? " " + "!!!".slice(0, x.prio) : "") + (x.due ? " @" + x.due : "");
}

// "today", "tomorrow", "fri", "24 oct", "3d late" …
function dueLabel(s) {
    if (!s) return "";
    var n = daysUntil(s);
    if (n < -1) return -n + "d late";
    if (n === -1) return "yesterday";
    if (n === 0) return "today";
    if (n === 1) return "tomorrow";
    var d = fromIso(s);
    if (n < 7) return dayNames[d.getDay()];
    return d.getDate() + " " + monthNames[d.getMonth()]
         + (d.getFullYear() !== new Date().getFullYear() ? " " + d.getFullYear() : "");
}

// ── the store ────────────────────────────────────────────────────
function db() {
    return Sql.LocalStorage.openDatabaseSync("todoDB", "1.0", "TODO List DB", 1000000);
}

// the first widget only had (text, done): add what's missing
function migrate(tx) {
    tx.executeSql("CREATE TABLE IF NOT EXISTS tasks(text TEXT, done INT)");
    var have = {};
    var rs = tx.executeSql("PRAGMA table_info(tasks)");
    for (var i = 0; i < rs.rows.length; i++) have[rs.rows.item(i).name] = true;
    var add = { prio: "INT DEFAULT 0", due: "TEXT DEFAULT ''", created: "INT DEFAULT 0", done_at: "INT DEFAULT 0" };
    for (var k in add)
        if (!have[k]) tx.executeSql("ALTER TABLE tasks ADD COLUMN " + k + " " + add[k]);
}

// → [{ title, done, prio, due, created, doneAt }] in list order
function load() {
    var out = [];
    db().transaction(function(tx) {
        migrate(tx);
        var rs = tx.executeSql("SELECT * FROM tasks ORDER BY rowid");
        for (var i = 0; i < rs.rows.length; i++) {
            var r = rs.rows.item(i);
            out.push({ title: String(r.text), done: r.done === 1, prio: r.prio || 0, due: r.due || "",
                       created: r.created || 0, doneAt: r.done_at || 0 });
        }
    });
    return out;
}

function save(rows) {
    db().transaction(function(tx) {
        migrate(tx);
        tx.executeSql("DELETE FROM tasks");
        for (var i = 0; i < rows.length; i++) {
            var x = rows[i];
            tx.executeSql("INSERT INTO tasks(text, done, prio, due, created, done_at) VALUES(?, ?, ?, ?, ?, ?)",
                          [x.title, x.done ? 1 : 0, x.prio || 0, x.due || "", x.created || 0, x.doneAt || 0]);
        }
    });
}

// where a new task goes: the end of the open ones, above the done block
function insertAt(rows) {
    var n = 0;
    for (var i = 0; i < rows.length; i++) if (!rows[i].done) n++;
    return n;
}

// quick-add from outside the widget; → the task, or null for an empty title
function add(text) {
    var e = parseEntry(text);
    if (!e.title) return null;
    var rows = load();
    var t = { title: e.title, done: false, prio: e.prio, due: e.due, created: Date.now(), doneAt: 0 };
    rows.splice(insertAt(rows), 0, t);
    save(rows);
    return t;
}
