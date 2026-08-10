pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Album art on disk, addressed by what it IS rather than where it came from.
//
// Two players, two problems, one answer. Chromium writes the cover to a temp
// file, then DELETES it and hands the same path back with different bytes on
// the next track -- so a path is neither stable nor unique. Spotify gives an
// https URL, which is stable but has to be fetched before it can be drawn.
// Both end up as one file in the cache: local files are keyed by the hash of
// their contents, remote ones by their URL.
Singleton {
    id: root

    readonly property string dir: Paths.cache + "/ashen_art"

    // Source url -> "file:///…" once it is on disk. Reassigned rather than
    // mutated: a JS object changed in place tells no binding anything.
    property var have: ({})

    // That url now has a file. Consumers check it is still the one they want.
    signal ready(string url)

    function local(url) { return url === "" ? "" : (root.have[url] || "") }

    // ── Telling a cover from the player's own icon ──────────────────────
    // With no artwork on the page, Chromium hands out Brave's logo as the
    // cover. Nothing about the file says so: it arrives by the same route, and
    // size is no help -- the logo comes at 256 px and real covers from the same
    // browser at 120. What gives it away is that it turns up under albums that
    // have nothing to do with each other. One album's tracks may share a cover;
    // two albums sharing one means it belongs to neither.
    property var tagsFor: ({})
    property var decoys: ({})

    function fileOf(url) {
        const p = root.have[url]
        return p === undefined ? "" : p.substring(p.lastIndexOf("/") + 1)
    }
    function isDecoy(url) {
        const f = root.fileOf(url)
        return f !== "" && root.decoys[f] === true
    }
    // `tag` is the album the cover came with (its artist, failing that). No
    // tag, no lesson: a loose file with no metadata teaches nothing.
    function note(url, tag) {
        const f = root.fileOf(url)
        if (f === "" || !tag) return
        let seen = root.tagsFor[f] || []
        if (seen.indexOf(tag) !== -1) return
        seen.push(tag)
        let t = root.tagsFor; t[f] = seen; root.tagsFor = t
        if (seen.length >= 2 && root.decoys[f] !== true) {
            let d = root.decoys; d[f] = true; root.decoys = d
            remember.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")"; printf "%s\\n" "$2" >> "$1"',
                               "sh", root.dir + "/.decoys", f]
            remember.running = true
        }
    }
    Process { id: remember; running: false }

    // What earlier sessions worked out. Cheap to reload, and it means the logo
    // only ever gets one chance to be shown.
    Process {
        running: true
        command: ["sh", "-c", 'cat "$1" 2>/dev/null || true', "sh", root.dir + "/.decoys"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = root.decoys
                text.trim().split("\n").forEach(l => { if (l !== "") d[l] = true })
                root.decoys = d
            }
        }
    }

    // djb2, base 36. Only has to be stable and short, not cryptographic.
    function keyOf(s) {
        let h = 5381
        for (let i = 0; i < s.length; i++) h = ((h * 33) ^ s.charCodeAt(i)) >>> 0
        return h.toString(36)
    }

    property var queue: []
    property string current: ""

    function request(url) {
        if (url === "") return
        // A remote URL names one image forever, so once fetched it is done. A
        // local path names whatever Chromium last wrote there -- it hands the
        // SAME temp name back with different bytes on the next track, so it has
        // to be hashed again every time or the last cover would be served for
        // the new one.
        if (root.have[url] !== undefined && !url.startsWith("file://")) {
            root.ready(url)
            return
        }
        // Same reason: a repeated local path is not a repeat request.
        if (!url.startsWith("file://") && (root.queue.indexOf(url) !== -1 || root.current === url)) return
        root.queue.push(url)
        root.pump()
    }

    function pump() {
        if (root.current !== "" || root.queue.length === 0) return
        root.current = root.queue.shift()
        const url = root.current
        if (url.startsWith("file://")) {
            // Content-addressed: the same cover under a recycled temp name
            // lands on the same file, a different one cannot collide with it.
            proc.command = ["sh", "-c",
                'set -e; mkdir -p "$1"; [ -s "$2" ] || exit 1; ' +
                'h=$(sha256sum "$2" | cut -c1-32); out="$1/$h"; ' +
                '[ -s "$out" ] || cp -f "$2" "$out"; printf %s "$out"',
                "sh", root.dir, url.substring(7)]
        } else {
            proc.command = ["sh", "-c",
                'set -e; mkdir -p "$1"; out="$1/$2"; ' +
                '[ -s "$out" ] || { curl -sfL --max-time 15 "$3" -o "$out.part"; mv -f "$out.part" "$out"; }; ' +
                'printf %s "$out"',
                "sh", root.dir, root.keyOf(url), url]
        }
        proc.running = true
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const url = root.current
                const path = text.trim()
                root.current = ""
                if (url !== "" && path !== "") {
                    let m = root.have
                    m[url] = "file://" + path
                    root.have = m
                    root.ready(url)
                }
                root.pump()
            }
        }
    }

    // Covers are small and the cache is not precious: keep the newest few
    // hundred and let the rest go, once, at startup.
    Process {
        running: true
        command: ["sh", "-c",
            'mkdir -p "$1"; cd "$1" || exit 0; ' +
            'ls -1t | tail -n +301 | while read -r f; do rm -f -- "$f"; done',
            "sh", root.dir]
    }
}
