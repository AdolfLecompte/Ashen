// Ashen — keybind cheatsheet, read from the real config.  by Adolf — github.com/AdolfLecompte
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Parses hypr/conf/keybinds.lua so Settings can list the shortcuts without a
// second copy of them: a duplicated table would drift the first time a bind
// changes. Anything the humaniser does not recognise is shown raw rather than
// dropped — a shortcut missing from the list is worse than an ugly one.
Singleton {
    id: root

    readonly property string confPath: Paths.home + "/.config/hypr/conf/keybinds.lua"
    readonly property string gesturePath: Paths.home + "/.config/hypr/conf/input.lua"

    // [{ section, keys, action }]
    property var binds: []
    // [{ keys, action }]
    property var gestures: []
    readonly property var sections: {
        let out = []
        for (const b of root.binds) {
            let s = out.find(x => x.name === b.section)
            if (!s) { s = { name: b.section, items: [] }; out.push(s) }
            s.items.push(b)
        }
        return out
    }

    // ── Parsing ───────────────────────────────────────────────────────────
    // Splits `hl.bind(a, b, c)` on the commas that sit at depth 1, ignoring the
    // ones inside strings or nested calls.
    function splitArgs(inner) {
        let args = [], depth = 0, quote = "", current = ""
        for (let i = 0; i < inner.length; i++) {
            const ch = inner[i]
            if (quote !== "") {
                current += ch
                if (ch === quote && inner[i - 1] !== "\\") quote = ""
                continue
            }
            if (ch === '"' || ch === "'") { quote = ch; current += ch; continue }
            if (ch === "(" || ch === "{") depth++
            if (ch === ")" || ch === "}") depth--
            if (ch === "," && depth === 0) { args.push(current.trim()); current = ""; continue }
            current += ch
        }
        if (current.trim() !== "") args.push(current.trim())
        return args
    }

    // "mod .. \" + SHIFT + W\"" -> "SUPER + SHIFT + W"
    function keysOf(expr, mod) {
        let out = ""
        for (const part of expr.split("..")) {
            const p = part.trim()
            if (p === "mod") out += mod
            else if (p === "i") out += "1…9"
            else {
                const m = p.match(/^"(.*)"$/)
                out += m ? m[1] : p
            }
        }
        return out.replace(/\s+/g, " ").trim()
    }

    // The shell's own IPC calls are the ones worth naming properly.
    function ipcLabel(cmd) {
        const m = cmd.match(/call\s+(\w+)\s+(\w+)/)
        if (!m) return ""
        const target = m[1], fn = m[2]
        const names = {
            "settings": "Settings", "notifications": "Notifications", "wallpaper": "Wallpaper picker",
            "clipboard": "Clipboard",
            "process": "Process monitor", "launcher": "Launcher", "lockscreen": "Lock screen",
            "power": "Power menu", "osd": "On-screen display", "media": "Media"
        }
        const label = names[target] !== undefined ? names[target] : target
        if (target === "media") {
            if (fn === "next") return "Next track"
            if (fn === "prev") return "Previous track"
            if (fn === "playPause") return "Play / pause"
        }
        if (fn === "toggle") return label
        if (target === "lockscreen") return label
        if (target === "notifications" && fn === "screenshot") return "Screenshot (area)"
        return label + " — " + fn
    }

    function actionOf(expr) {
        let m = expr.match(/^hl\.dsp\.exec_cmd\(\s*"([\s\S]*)"\s*\)$/)
        if (m) {
            const cmd = m[1]
            // What the bind DOES comes first: the media keys also fire an OSD
            // ipc call, and naming them after that would call them all "volume".
            if (cmd.indexOf("grimblast") !== -1) return "Screenshot (area)"
            if (cmd.indexOf("wpctl set-mute") !== -1 && cmd.indexOf("toggle") !== -1) return "Mute"
            if (cmd.indexOf("5%+") !== -1) return cmd.indexOf("brightnessctl") !== -1 ? "Brightness up" : "Volume up"
            if (cmd.indexOf("5%-") !== -1) return cmd.indexOf("brightnessctl") !== -1 ? "Brightness down" : "Volume down"
            const ipc = root.ipcLabel(cmd)
            if (ipc !== "") return ipc
            // Bare app launches read fine as they are
            const bare = cmd.replace(/^sh -c '/, "").replace(/'$/, "")
            return bare.split(" ")[0]
        }
        if (expr.indexOf("window.close") !== -1) return "Close window"
        if (expr.indexOf("window.fullscreen") !== -1) return "Fullscreen"
        if (expr.indexOf("window.float") !== -1) return "Toggle floating"
        if (expr.indexOf("window.pseudo") !== -1) return "Pseudo tile"
        if (expr.indexOf("window.drag") !== -1) return "Move window with the mouse"
        if (expr.indexOf("window.resize") !== -1) return "Resize window with the mouse"

        m = expr.match(/window\.move\(\s*\{\s*workspace\s*=\s*"?([\w+-]+)"?/)
        if (m) return "Move window to " + root.workspaceLabel(m[1])
        m = expr.match(/focus\(\s*\{\s*workspace\s*=\s*"?([\w+-]+)"?/)
        if (m) return "Go to " + root.workspaceLabel(m[1])
        m = expr.match(/focus\(\s*\{\s*direction\s*=\s*"(\w+)"/)
        if (m) return "Focus " + m[1]
        m = expr.match(/workspace\.toggle_special\(\s*"(\w+)"/)
        if (m) return "Special workspace: " + m[1]

        return expr   // shown raw rather than dropped
    }

    function workspaceLabel(v) {
        if (v === "e+1") return "the next workspace"
        if (v === "e-1") return "the previous workspace"
        if (v === "i") return "that workspace"
        return "workspace " + v
    }

    function parse(text) {
        const lines = text.split("\n")
        let mod = "SUPER", section = "General", out = []

        for (let raw of lines) {
            const line = raw.trim()

            const modMatch = line.match(/^local\s+mod\s*=\s*"(\w+)"/)
            if (modMatch) { mod = modMatch[1]; continue }

            // Section headers are the plain comments; the banner rules are not
            if (line.startsWith("--")) {
                const body = line.replace(/^--+/, "").trim()
                if (body !== "" && body.indexOf("═") === -1 && body.indexOf("Ashen") === -1) {
                    // Comments explain; headings label. Drop the explanation.
                    section = body.split(":")[0].replace(/\s*\(.*\)\s*$/, "").trim()
                }
                continue
            }

            if (line.indexOf("hl.bind(") !== 0) continue
            const inner = line.substring("hl.bind(".length, line.lastIndexOf(")"))
            const args = root.splitArgs(inner)
            if (args.length < 2) continue

            out.push({
                section: section,
                keys: root.keysOf(args[0], mod),
                action: root.actionOf(args[1])
            })
        }
        return out
    }

    FileView {
        path: root.confPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.binds = root.parse(text())
        onLoadFailed: root.binds = []
    }

    // ── Touchpad gestures (input.lua) ──────────────────────────────────
    // Gestures are multi-line blocks, so the line-by-line parser above does not
    // see them. Same best-effort rule: anything unrecognised is shown raw.
    function extractGestures(text) {
        let out = [], i = 0
        while (true) {
            i = text.indexOf("hl.gesture(", i)
            if (i === -1) break
            const open = text.indexOf("{", i)
            if (open === -1) break
            let depth = 0, quote = "", j = open, ch
            for (; j < text.length; j++) {
                ch = text[j]
                if (quote !== "") {
                    if (ch === quote && text[j - 1] !== "\\") quote = ""
                    continue
                }
                if (ch === '"' || ch === "'") { quote = ch; continue }
                if (ch === "{") depth++
                else if (ch === "}") { depth--; if (depth === 0) { j++; break } }
            }
            out.push(text.slice(open, j))
            i = j
        }
        return out
    }

    function gestureKeys(block) {
        const m = block.match(/fingers\s*=\s*(\d+)/)
        const d = block.match(/direction\s*=\s*"([^"]*)"/)
        const dirNames = {
            "swipe": "any direction", "horizontal": "horizontal", "vertical": "vertical",
            "left": "left", "right": "right", "up": "up", "down": "down",
            "pinch": "pinch", "pinchin": "pinch in", "pinchout": "pinch out"
        }
        const dir = d && dirNames[d[1]] !== undefined ? dirNames[d[1]] : (d ? d[1] : "?")
        return (m ? m[1] : "?") + " fingers · " + dir
    }

    function gestureAction(block) {
        // A lambda calling the shell's own IPC names itself after the overlay
        const ipc = block.match(/hl\.exec_cmd\(\s*"qs ipc -c ashen call (\w+) (\w+)"/)
        if (ipc) {
            const label = root.ipcLabel("call " + ipc[1] + " " + ipc[2])
            return label !== "" ? label : ipc[1]
        }
        const a = block.match(/action\s*=\s*"([^"]+)"/)
        if (a) {
            const names = {
                "workspace": "Switch workspaces", "move": "Move active window",
                "resize": "Resize active window", "special": "Toggle special workspace",
                "close": "Close active window", "fullscreen": "Fullscreen",
                "float": "Toggle floating", "cursorZoom": "Zoom into cursor",
                "scroll_move": "Scroll the tape"
            }
            return names[a[1]] !== undefined ? names[a[1]] : a[1]
        }
        if (block.indexOf("function") !== -1) return "Custom action"
        return "Unknown"
    }

    function parseGestures(text) {
        return root.extractGestures(text).map(block => ({
            keys: root.gestureKeys(block),
            action: root.gestureAction(block)
        }))
    }

    FileView {
        path: root.gesturePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.gestures = root.parseGestures(text())
        onLoadFailed: root.gestures = []
    }
}
