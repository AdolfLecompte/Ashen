pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var devices: []

    function refresh() { scanProc.running = true }

    function isRemovable(n) {
        return n.rm === true || n.rm === "1" || n.rm === 1
    }

    Process {
        id: scanProc
        command: ["sh", "-c", "lsblk -J -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,RM,TYPE 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text)
                    let list = []
                    for (let dev of (data.blockdevices || [])) {
                        if (dev.type === "disk" && root.isRemovable(dev)) {
                            let parts = (dev.children || []).filter(c => c.type === "part" && c.fstype !== "swap")
                            if (parts.length === 0) {
                                list.push({
                                    name: dev.name,
                                    path: "/dev/" + dev.name,
                                    size: dev.size || "",
                                    label: (dev.label && dev.label.length > 0) ? dev.label : dev.name,
                                    fstype: dev.fstype || "",
                                    mountpoint: dev.mountpoint || "",
                                    parentName: dev.name
                                })
                            } else {
                                for (let p of parts) {
                                    list.push({
                                        name: p.name,
                                        path: "/dev/" + p.name,
                                        size: p.size || "",
                                        label: (p.label && p.label.length > 0) ? p.label : p.name,
                                        fstype: p.fstype || "",
                                        mountpoint: p.mountpoint || "",
                                        parentName: dev.name
                                    })
                                }
                            }
                        }
                    }
                    root.devices = list
                } catch (e) {
                    console.warn("[USB] parse error:", e)
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshDelay
        interval: 800
        repeat: false
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()

    function mount(path) {
        Quickshell.execDetached(["udisksctl", "mount", "-b", path])
        refreshDelay.restart()
    }
    function unmount(path) {
        Quickshell.execDetached(["udisksctl", "unmount", "-b", path])
        refreshDelay.restart()
    }
    function eject(parentName) {
        Quickshell.execDetached(["sh", "-c",
            "for p in /dev/" + parentName + "?*; do udisksctl unmount -b \"$p\" 2>/dev/null; done; udisksctl power-off -b /dev/" + parentName
        ])
        refreshDelay.restart()
    }
}
