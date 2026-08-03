// Ashen — quick notes kept as plain Markdown files.  by Adolf — github.com/AdolfLecompte
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

import "root:/services" as Services

// One note per file, in a folder you pick. Nothing is stored in a database of
// ours: what you write is a .md you can open in any editor, sync, or grep.
//
// The text being edited lives HERE, not in the panel. A note half written when
// you close the panel is still a note, and the panel is destroyed and rebuilt
// every time it opens.
Singleton {
    id: root

    readonly property string dir: Services.Prefs.notesDir !== ""
        ? Services.Prefs.notesDir : Services.Paths.notes

    // Which folder is open, relative to `dir`. "" is the root.
    property string folder: ""
    readonly property string cwd: root.folder === "" ? root.dir : root.dir + "/" + root.folder
    // The trail back out, for the breadcrumb: ["", "work", "work/2026"].
    readonly property var crumbs: {
        if (root.folder === "") return [""]
        const parts = root.folder.split("/")
        let acc = []; let out = [""]
        for (const p of parts) { acc.push(p); out.push(acc.join("/")) }
        return out
    }
    function enter(rel) { root.flush(); root.folder = rel; root.close(); root.refresh() }
    function up() {
        if (root.folder === "") return
        const i = root.folder.lastIndexOf("/")
        root.enter(i === -1 ? "" : root.folder.substring(0, i))
    }

    // Subfolders of the open folder: [{ name, rel, count }]
    property var folders: []
    // [{ file, title, mtime }], newest first.
    property var notes: []
    // Which file is open, and its text as it stands right now.
    property string current: ""
    property string draft: ""
    // True between a keystroke and the write landing.
    property bool dirty: false
    property bool loading: false

    function fileTitle(name) {
        for (const n of root.notes)
            if (n.file === name) return n.title
        return ""
    }

    // ── Listing ─────────────────────────────────────────────────────────
    function refresh() { listProc.running = false; listProc.running = true }

    Process {
        id: listProc
        running: false
        // Folders first (marked "d"), then each note's mtime, name and first
        // line. One process for the whole listing, whatever is in it.
        command: ["sh", "-c",
                  'mkdir -p "$1" && cd "$1" || exit 0; ' +
                  'for d in */; do [ -d "$d" ] || continue; ' +
                  'n=$(find "$d" -maxdepth 1 -name "*.md" | wc -l); ' +
                  'printf "d\\t%s\\t%s\\n" "${d%/}" "$n"; done | sort; ' +
                  'for f in *.md; do [ -e "$f" ] || continue; ' +
                  'printf "f\\t%s\\t%s\\t%s\\n" "$(stat -c %Y "$f")" "$f" ' +
                  '"$(head -n1 "$f" | tr -d "\\r" | cut -c1-90)"; done | sort -rn -k2',
                  "sh", root.cwd]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = []
                let dirs = []
                for (const line of text.split("\n")) {
                    if (line.trim() === "") continue
                    const p = line.split("\t")
                    if (p[0] === "d") {
                        if (p.length < 3) continue
                        dirs.push({ name: p[1],
                                    rel: root.folder === "" ? p[1] : root.folder + "/" + p[1],
                                    count: parseInt(p[2]) || 0 })
                        continue
                    }
                    if (p.length < 4) continue
                    // The FILE NAME is the title, the way Obsidian does it: a
                    // note that opens with front matter or a blank line still
                    // has a name, and the name is what you gave it. The first
                    // line rides along as the preview.
                    const name = p[2].replace(/\.md$/i, "")
                    const raw = (p[3] || "").replace(/^#+\s*/, "").trim()
                    out.push({ file: p[2],
                               title: name,
                               preview: raw,
                               mtime: parseInt(p[1]) * 1000 })
                }
                root.folders = dirs
                root.notes = out
                // Whatever was open may have been deleted from outside.
                if (root.current !== "" && !out.some(n => n.file === root.current))
                    root.close()
            }
        }
    }

    // ── Opening ─────────────────────────────────────────────────────────
    function open(file) {
        if (file === root.current) return
        root.flush()
        root.current = file
        root.draft = ""
        root.loading = true
        readProc.running = false
        readProc.command = ["sh", "-c", 'cat -- "$1" 2>/dev/null', "sh", root.cwd + "/" + file]
        readProc.running = true
    }

    function close() {
        root.flush()
        root.current = ""
        root.draft = ""
    }

    Process {
        id: readProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.draft = text
                root.loading = false
                root.dirty = false
            }
        }
    }

    // ── Editing ─────────────────────────────────────────────────────────
    // Called by the editor on every keystroke; the write itself is coalesced.
    function edit(text) {
        if (root.loading || root.current === "") return
        // Editing in Markdown means Qt re-emits the source it parsed, which
        // differs from the file by a trailing newline. Without this, merely
        // OPENING a note counted as a change: it would be rewritten, its mtime
        // would move, and it would jump to the top of the list unread.
        if (text.replace(/\s+$/, "") === root.draft.replace(/\s+$/, "")) {
            root.draft = text
            return
        }
        root.draft = text
        root.dirty = true
        saveDebounce.restart()
    }

    Timer {
        id: saveDebounce
        interval: 600
        onTriggered: root.flush()
    }

    // Write now. Called on close and on switching notes as well, so nothing
    // waits on a timer that may never fire.
    function flush() {
        saveDebounce.stop()
        if (!root.dirty || root.current === "") return
        root.dirty = false
        writeProc.running = false
        // Through a temp file and a rename: a redirection truncates the real
        // note the instant the shell starts, so a write cut short would leave
        // it empty. Same rule as the notification history.
        writeProc.command = ["sh", "-c",
                             'mkdir -p "$(dirname "$2")" && printf %s "$1" > "$2.tmp" && mv -f "$2.tmp" "$2"',
                             "sh", root.draft, root.cwd + "/" + root.current]
        writeProc.running = true
    }

    Process {
        id: writeProc
        running: false
        onExited: root.refresh()
    }

    // ── Creating and removing ───────────────────────────────────────────
    function create() {
        root.flush()
        const d = new Date()
        const p = n => (n < 10 ? "0" : "") + n
        const name = "note-" + d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate())
                   + "-" + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds()) + ".md"
        newProc.running = false
        newProc.command = ["sh", "-c",
                           'mkdir -p "$1" && : > "$1/$2"', "sh", root.cwd, name]
        root.pendingNew = name
        newProc.running = true
    }
    property string pendingNew: ""

    Process {
        id: newProc
        running: false
        onExited: {
            const name = root.pendingNew
            root.pendingNew = ""
            root.refresh()
            if (name !== "") {
                root.current = name
                root.draft = ""
                root.dirty = false
            }
        }
    }

    // New folder inside the one that is open. Names are taken literally, so a
    // slash makes a nested one -- the same as typing it in a file manager.
    function createFolder(name) {
        const clean = String(name).replace(/^\/+|\/+$/g, "")
        if (clean === "") return
        mkdirProc.running = false
        mkdirProc.command = ["sh", "-c", 'mkdir -p -- "$1/$2"', "sh", root.cwd, clean]
        mkdirProc.running = true
    }
    Process { id: mkdirProc; running: false; onExited: root.refresh() }

    function removeFolder(rel) {
        // Only if it is empty: a notes panel has no business deleting a tree.
        rmdirProc.running = false
        rmdirProc.command = ["sh", "-c", 'rmdir -- "$1/$2" 2>/dev/null', "sh", root.dir, rel]
        rmdirProc.running = true
    }
    Process { id: rmdirProc; running: false; onExited: root.refresh() }

    function remove(file) {
        if (file === root.current) { root.dirty = false; root.close() }
        rmProc.running = false
        rmProc.command = ["sh", "-c", 'rm -f -- "$1"', "sh", root.cwd + "/" + file]
        rmProc.running = true
    }

    Process {
        id: rmProc
        running: false
        onExited: root.refresh()
    }

    // A folder that moves is a different set of notes.
    onDirChanged: { root.folder = ""; root.current = ""; root.draft = ""; root.dirty = false; root.refresh() }
    Component.onCompleted: root.refresh()
}
