pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Hardware stats + process list. Everything here used to live inside
// SettingsSystemTab; it now feeds the Process panel instead.
// Polling only runs while `active` is true, so nothing is sampled unless
// the panel is on screen.
Singleton {
    id: root

    property bool active: false

    property real cpuPercent: 0
    property string cpuModel: "..."
    property real cpuTemp: 0
    property real prevCpuTotal: 0
    property real prevCpuIdle: 0

    property real ramUsedMB: 0
    property real ramTotalMB: 0

    property real diskUsedGB: 0
    property real diskTotalGB: 0
    property int diskPercent: 0

    property string gpuInfo: "..."
    property real gpuUsage: 0
    property real gpuTemp: 0
    property bool hasGpuStats: false
    // hybrid laptop: the dGPU sleeps (runtime_status = suspended) and polling
    // nvidia-smi would wake it up, so fall back to the iGPU clock instead
    property bool dgpuAwake: false
    property real igpuFreq: 0
    property real igpuMaxFreq: 0
    // dGPU asleep: report how hard the iGPU is clocking instead
    readonly property real gpuPercent: dgpuAwake
        ? gpuUsage
        : (igpuMaxFreq > 0 ? (igpuFreq / igpuMaxFreq) * 100 : 0)

    property real netRxKBs: 0
    property real netTxKBs: 0
    property real prevRxBytes: -1
    property real prevTxBytes: -1

    // [{ pid, name, cpu, mem }], heaviest first


    onActiveChanged: if (active) {
        // the static bits only need one read, ever
        if (cpuModel === "...") cpuModelProc.running = true
        if (gpuInfo === "...") gpuProc.running = true
        // rates need two samples, so drop the stale baseline
        prevRxBytes = -1
        prevTxBytes = -1
        sample()
        diskProc.running = true
    }

    function sample() {
        cpuProc.running = true
        ramProc.running = true
        netProc.running = true
        sensorsProc.running = true
        gpuStatProc.running = true
    }

    Timer {
        interval: 1500
        running: root.active
        repeat: true
        onTriggered: root.sample()
    }
    Timer {
        interval: 10000
        running: root.active
        repeat: true
        onTriggered: diskProc.running = true
    }

    Process {
        id: cpuModelProc
        command: ["sh", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.cpuModel = text.trim() }
    }

    Process {
        id: cpuProc
        command: ["sh", "-c", "grep '^cpu ' /proc/stat"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = text.trim().split(/\s+/).slice(1).map(Number)
                let idle = parts[3] + (parts[4] || 0)
                let total = parts.reduce((a, b) => a + b, 0)
                if (root.prevCpuTotal > 0) {
                    let totalDiff = total - root.prevCpuTotal
                    let idleDiff = idle - root.prevCpuIdle
                    if (totalDiff > 0) {
                        root.cpuPercent = Math.max(0, Math.min(100, 100 * (1 - idleDiff / totalDiff)))
                    }
                }
                root.prevCpuTotal = total
                root.prevCpuIdle = idle
            }
        }
    }

    Process {
        id: sensorsProc
        command: ["sh", "-c", "sensors 2>/dev/null | grep -iE 'Package id 0|Tctl|Tdie' | head -1 | grep -oE '[0-9]+\\.[0-9]+' | head -1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let t = parseFloat(text.trim())
                root.cpuTemp = isNaN(t) ? 0 : t
            }
        }
    }

    Process {
        id: ramProc
        command: ["sh", "-c", "free -m | awk '/^Mem:/{print $3\",\"$2}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = text.trim().split(",")
                if (parts.length === 2) {
                    root.ramUsedMB = parseFloat(parts[0]) || 0
                    root.ramTotalMB = parseFloat(parts[1]) || 0
                }
            }
        }
    }

    Process {
        id: diskProc
        command: ["sh", "-c", "df -BG --output=used,size,pcent / | tail -1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = text.trim().split(/\s+/)
                if (parts.length === 3) {
                    root.diskUsedGB = parseFloat(parts[0].replace("G", "")) || 0
                    root.diskTotalGB = parseFloat(parts[1].replace("G", "")) || 0
                    root.diskPercent = parseInt(parts[2].replace("%", "")) || 0
                }
            }
        }
    }

    Process {
        id: gpuProc
        command: ["sh", "-c", "lspci | grep -E 'VGA|3D controller'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n").filter(l => l.length > 0)
                root.gpuInfo = lines.length > 0 ? lines.map(l => l.split(": ").pop()).join(" / ") : "Unknown"
            }
        }
    }

    Process {
        id: gpuStatProc
        command: ["sh", "-c",
            "DEV=$(ls -d /sys/bus/pci/drivers/nvidia/0000:* 2>/dev/null | head -1); "
            + "ST=''; [ -n \"$DEV\" ] && ST=$(cat \"$DEV/power/runtime_status\" 2>/dev/null); "
            + "if [ \"$ST\" = active ]; then nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null; else echo asleep; fi; "
            + "cat /sys/class/drm/card*/gt_cur_freq_mhz /sys/class/drm/card*/gt_max_freq_mhz 2>/dev/null | head -2"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n").map(l => l.trim()).filter(l => l.length > 0)
                let head = lines.length > 0 ? lines[0] : "asleep"
                if (head.indexOf(",") !== -1) {
                    let parts = head.split(",").map(v => parseFloat(v.trim()))
                    root.gpuUsage = parts[0] || 0
                    root.gpuTemp = parts[1] || 0
                    root.dgpuAwake = true
                    root.hasGpuStats = true
                } else {
                    root.dgpuAwake = false
                    root.hasGpuStats = false
                    root.gpuUsage = 0
                    root.gpuTemp = 0
                }
                root.igpuFreq = lines.length > 1 ? (parseFloat(lines[1]) || 0) : 0
                root.igpuMaxFreq = lines.length > 2 ? (parseFloat(lines[2]) || 0) : 0
            }
        }
    }

    Process {
        id: netProc
        command: ["sh", "-c", "cat /proc/net/dev | tail -n +3 | awk '{sub(\":\",\"\",$1); if ($1!=\"lo\") {rx+=$2; tx+=$10}} END {print rx\",\"tx}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = text.trim().split(",")
                if (parts.length === 2) {
                    let rx = parseFloat(parts[0]) || 0
                    let tx = parseFloat(parts[1]) || 0
                    if (root.prevRxBytes >= 0) {
                        root.netRxKBs = Math.max(0, (rx - root.prevRxBytes) / 1024 / 1.5)
                        root.netTxKBs = Math.max(0, (tx - root.prevTxBytes) / 1024 / 1.5)
                    }
                    root.prevRxBytes = rx
                    root.prevTxBytes = tx
                }
            }
        }
    }

}
