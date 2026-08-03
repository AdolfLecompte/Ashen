import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services
import "root:/modules/settings/components"

// TabPage, like every other tab: on its own this was a bare ColumnLayout with
// no Flickable, so it was the one section in Settings that could not be
// scrolled and anything past the fold was simply unreachable.
TabPage {
    id: tab

    property string osName: "..."
    property string kernel: "..."
    property string hostname: "..."
    property string uptime: "..."
    property string product: "..."
    property string board: "..."
    property string cpuInfo: "..."
    property string gpuInfo: "..."
    property string memInfo: "..."
    property string diskInfo: "..."
    property string pkgInfo: "..."
    property string monitorInfo: "..."
    property bool copied: false

    Component.onCompleted: {
        basicProc.running = true
        hwProc.running = true
        cpuProc.running = true
        gpuProc.running = true
        memProc.running = true
        diskProc.running = true
        pkgProc.running = true
        monProc.running = true
    }

    Process {
        id: basicProc
        command: ["sh", "-c", ". /etc/os-release; echo \"$PRETTY_NAME|$(uname -r)|$(hostnamectl hostname 2>/dev/null || hostname)|$(uptime -p)\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let p = text.trim().split("|")
                tab.osName = p[0] || ""
                tab.kernel = p[1] || ""
                tab.hostname = p[2] || ""
                tab.uptime = p[3] || ""
            }
        }
    }
    Process {
        id: hwProc
        command: ["sh", "-c", "echo \"$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)|$(cat /sys/devices/virtual/dmi/id/board_name 2>/dev/null)\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let p = text.trim().split("|")
                tab.product = p[0] || ""
                tab.board = p[1] || ""
            }
        }
    }
    Process {
        id: cpuProc
        command: ["sh", "-c", "echo \"$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//') ($(nproc) threads)\""]
        running: false
        stdout: StdioCollector { onStreamFinished: tab.cpuInfo = text.trim() }
    }
    Process {
        id: gpuProc
        command: ["sh", "-c", "lspci | grep -E 'VGA|3D controller' | sed 's/^[^:]*: //' | paste -sd '/'"]
        running: false
        stdout: StdioCollector { onStreamFinished: tab.gpuInfo = text.trim() }
    }
    Process {
        id: memProc
        command: ["sh", "-c", "free -h | awk '/^Mem:/{print $3\"/\"$2}'"]
        running: false
        stdout: StdioCollector { onStreamFinished: tab.memInfo = text.trim() }
    }
    Process {
        id: diskProc
        command: ["sh", "-c", "df -h --output=used,size / | tail -1 | awk '{print $1\"/\"$2}'"]
        running: false
        stdout: StdioCollector { onStreamFinished: tab.diskInfo = text.trim() }
    }
    Process {
        id: pkgProc
        command: ["sh", "-c", "echo \"$(pacman -Qq 2>/dev/null | wc -l) packages\""]
        running: false
        stdout: StdioCollector { onStreamFinished: tab.pkgInfo = text.trim() }
    }
    Process {
        id: monProc
        command: ["sh", "-c", "hyprctl monitors | grep -E 'Monitor|resolution' | tr '\\n' ' ' | sed 's/  */ /g'"]
        running: false
        stdout: StdioCollector { onStreamFinished: tab.monitorInfo = text.trim() }
    }

    Process { id: copyProc; running: false }
    function copyInfo() {
        let info = "OS: " + tab.osName + "\\n" +
            "Kernel: " + tab.kernel + "\\n" +
            "Host: " + tab.hostname + "\\n" +
            "Product: " + tab.product + "\\n" +
            "Board: " + tab.board + "\\n" +
            "Uptime: " + tab.uptime + "\\n" +
            "CPU: " + tab.cpuInfo + "\\n" +
            "GPU: " + tab.gpuInfo + "\\n" +
            "Memory: " + tab.memInfo + "\\n" +
            "Disk: " + tab.diskInfo + "\\n" +
            "Packages: " + tab.pkgInfo + "\\n" +
            "Monitor: " + tab.monitorInfo
        copyProc.command = ["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", info]
        copyProc.running = true
        tab.copied = true
        copiedTimer.restart()
    }
    Timer { id: copiedTimer; interval: 1500; onTriggered: tab.copied = false }

    RowLayout {
        Layout.fillWidth: true
        Text {
            visible: false   // the drawer header carries the section name
            text: "About"
            color: Services.Colors.snow
            font.pixelSize: 20
            font.bold: true
            font.family: "JetBrainsMono NF"
            Layout.fillWidth: true
        }
        Rectangle {
            width: copyRow.implicitWidth + 18
            height: 32
            radius: 8
            color: tab.copied ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.15)
            gradient: Services.Prefs.useGradients && (tab.copied) ? Services.Colors.accentGradient : null
            Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
            RowLayout {
                id: copyRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: tab.copied ? "" : ""
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 14
                    color: tab.copied ? Services.Colors.accentText : Services.Colors.ghost
                }
                Text {
                    text: tab.copied ? "Copied" : "Copy Info"
                    color: tab.copied ? Services.Colors.accentText : Services.Colors.snow
                    font.pixelSize: 12
                    font.family: "JetBrainsMono NF"
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: tab.copyInfo()
            }
        }
    }


    // The face the lock screen and the launcher show. It belongs with who
    // the machine is, not with how it is painted.
    PreviewCard {
        source: Services.AppState.facePath
        fallbackGlyph: "\uf0d3"
        title: "Profile Picture"
        subtitle: Services.AppState.userLabel
        action: "Change"
        onTriggered: facePickProc.running = true
    }

    Process {
        id: facePickProc
        command: ["sh", "-c", "zenity --file-selection --title='Choose profile picture' --file-filter='Images | *.png *.jpg *.jpeg' 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let path = text.trim()
                if (path.length > 0 && Services.AppState.homeDir !== "") {
                    faceCopyProc.command = ["cp", path, Services.AppState.homeDir + "/.face"]
                    faceCopyProc.running = true
                }
            }
        }
    }
    Process {
        id: faceCopyProc
        running: false
        onExited: Services.AppState.faceVersion = Date.now()
    }

    Divider {}

    ColumnLayout {
        Layout.topMargin: 6
        spacing: 5

        Repeater {
            model: [
                { label: "OS", value: tab.osName },
                { label: "Kernel", value: tab.kernel },
                { label: "Host", value: tab.hostname },
                { label: "Product", value: tab.product },
                { label: "Board", value: tab.board },
                { label: "Uptime", value: tab.uptime },
                { label: "CPU", value: tab.cpuInfo },
                { label: "GPU", value: tab.gpuInfo },
                { label: "Memory", value: tab.memInfo },
                { label: "Disk", value: tab.diskInfo },
                { label: "Packages", value: tab.pkgInfo },
                { label: "Monitor", value: tab.monitorInfo },
            ]
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: modelData.label
                    color: Services.Colors.mist
                    font.pixelSize: 12
                    font.family: "JetBrainsMono NF"
                    Layout.preferredWidth: 80
                }
                Text {
                    text: modelData.value
                    color: Services.Colors.snow
                    font.pixelSize: 12
                    font.family: "JetBrainsMono NF"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }

    Divider { Layout.topMargin: 10; Layout.bottomMargin: 4 }

    ColumnLayout {
        spacing: 4
        Text {
            text: "ASHEN"
            color: Services.Colors.snow
            font.pixelSize: 26
            font.bold: true
            font.family: "JetBrainsMono NF"
            font.letterSpacing: 2
        }
        Text {
            text: "A monochrome Hyprland shell, built with Quickshell"
            color: Services.Colors.mist
            font.pixelSize: 12
            font.family: "JetBrainsMono NF"
        }
        Text {
            text: "by Adolf"
            color: Services.Colors.ash
            font.pixelSize: 11
            font.family: "JetBrainsMono NF"
            Layout.topMargin: 2
        }
    }

    Rectangle {
        Layout.topMargin: 12
        width: repoRow.implicitWidth + 24
        height: 40
        radius: 10
        color: Services.Colors.ghostAlpha(0.15)
        RowLayout {
            id: repoRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                text: ""
                font.family: "Material Symbols Rounded"
                font.pixelSize: 16
                color: Services.Colors.ghost
            }
            Text {
                text: "github.com/AdolfLecompte/ashen"
                color: Services.Colors.snow
                font.pixelSize: 12
                font.family: "JetBrainsMono NF"
            }
            Text {
                text: ""
                font.family: "Material Symbols Rounded"
                font.pixelSize: 14
                color: Services.Colors.mist
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: parent.color = Services.Colors.ghostAlpha(0.25)
            onExited: parent.color = Services.Colors.ghostAlpha(0.15)
            onClicked: Quickshell.execDetached(["sh", "-c", "xdg-open https://github.com/AdolfoLecompteDev/ashen"])
        }
    }
}
