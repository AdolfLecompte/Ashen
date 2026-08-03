import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/modules/widgets" as Widgets
import "root:/services" as Services
import "root:/modules/settings/components"

PanelWindow {
    id: win
    anchors { top: true; left: true; right: true; bottom: true }
    screen: Services.Screens.active
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stays mapped through the close animation, so the exit plays in reverse
    readonly property bool shown: Services.AppState.settingsVisible
    visible: shown || closeDelay.running
    onShownChanged: if (!shown) closeDelay.restart()
    Timer { id: closeDelay; interval: card.closeMs }

    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // One tab per question the user is actually asking ("how does the bar look?",
    // "what is this machine talking to?"). Wi-Fi and Bluetooth share one, since
    // they are the same question, and each tab is small enough to scan.
    // Where the section you picked sits in the rail, so the slide knows which
    // way it moved.
    readonly property int tabIndex: {
        for (let i = 0; i < win.categories.length; i++)
            if (win.categories[i].id === Services.AppState.settingsTab) return i
        return 0
    }

    property var categories: [
        { id: "system", icon: "\ue429", label: "System" },
        { id: "bar", icon: "\ue98c", label: "Bar" },
        { id: "display", icon: "\ueb97", label: "Display" },
        { id: "sound", icon: "\ue050", label: "Sound" },
        { id: "network", icon: "\ue1ba", label: "Network" },
        { id: "input", icon: "\ue312", label: "Input" },
        { id: "notifications", icon: "\ue7f5", label: "Notifications" },
        { id: "theme", icon: "\ue40a", label: "Appearance" },
        { id: "about", icon: "\ue88e", label: "About" },
    ]

    function tabSource(id) {
        // "wifi" and "bluetooth" still resolve: they were tab ids of their own
        // before the Network merge, and old ipc calls or launcher entries may
        // still ask for them.
        if (id === "wifi" || id === "bluetooth" || id === "network") return "SettingsNetworkTab.qml"
        if (id === "system") return "SettingsSystemTab.qml"
        if (id === "bar") return "SettingsBarTab.qml"
        if (id === "display") return "SettingsDisplayTab.qml"
        if (id === "sound") return "SettingsSoundTab.qml"
        if (id === "input") return "SettingsInputTab.qml"
        if (id === "notifications") return "SettingsNotificationsTab.qml"
        if (id === "theme") return "SettingsThemeTab.qml"
        if (id === "about") return "SettingsAboutTab.qml"
        return ""
    }

    // Wi-Fi and Bluetooth were tabs of their own before the Network merge and
    // still arrive from old ipc calls, so they light the Network row.
    readonly property string activeId: {
        const t = Services.AppState.settingsTab
        return (t === "wifi" || t === "bluetooth") ? "network" : t
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.settingsVisible = false
    }

    FocusScope {
        anchors.fill: parent
        focus: win.shown
        Keys.onEscapePressed: Services.AppState.settingsVisible = false
    }

    // Out of the settings chip on the utility pill, like Process and Clipboard.
    // It used to slide in from the right edge with nothing behind it, because
    // Settings had no pill of its own to leave.
    // Live from the pill, not a value written when something was clicked:
    // a keybind never clicks, and the panel used to grow from wherever the
    // last click had left the numbers.
        readonly property string srcEdge: Services.AppState.settingsSourceEdge
    // Its chip: on the utility pill of that edge, or on the bar.
    readonly property var chipRect: Services.AppState.chipRectOf("settings", win.srcEdge)
    readonly property real openXCalc: srcEdge === "" ? NaN
        : srcEdge === "left" ? Services.Sizes.panelTop
        : srcEdge === "right" ? win.width - card.openW - Services.Sizes.panelTop
        : (win.width - card.openW) / 2
    readonly property real openYCalc: srcEdge === "" ? NaN
        : srcEdge === "top" ? Services.Sizes.panelTop
        : srcEdge === "bottom" ? win.height - card.openH - Math.max(68, Services.Sizes.marginBottom + 18)
        : (win.height - card.openH) / 2

    Widgets.PanelHost {
        id: card
        shown: win.shown
        sourceEdge: win.srcEdge
        openXOverride: win.openXCalc
        openYOverride: win.openYCalc

        pillCX: win.chipRect.cx
        pillCY: win.chipRect.cy
        pillW: win.chipRect.w
        pillH: win.chipRect.h

        // Wide, not a tall narrow drawer. The rail used to run across the top
        // because the drawer was a narrow column and a second vertical strip
        // inside it fought the content for width -- but nine icon-only tabs in
        // a row said nothing about where you were, and the content underneath
        // had a column's worth of room to lay settings out in. Sideways there
        // is room for both.
        // Sized off the bar layout editor, the widest thing in here: three
        // drop plates side by side, each wanting room for a couple of pill
        // chips before they wrap. At 1000x620 they took one chip per line and
        // the picture of the bar read as three cramped columns.
        openW: Math.min(1240, win.width - 60)
        openH: Math.min(800, win.height - 80)
        cardRadius: Services.Sizes.panelR

        pillKey: "settings"
        restSide: "right"

        body: Component {
            Item {
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    // ── Left: where you are ────────────────────────────
                    // One accent that TRAVELS between the sections, the way the
                    // workspace strip does, instead of a plate per row lighting up.
                    // A box around every item made nine outlines compete with the
                    // content; with the indicator doing the work the rail is just
                    // words, and the movement says which one you picked.
                    Item {
                        Layout.fillWidth: false
                        Layout.preferredWidth: 190
                        Layout.fillHeight: true

                        readonly property int rowH: 36
                        readonly property int gap: 2

                        Rectangle {
                            id: slide
                            width: parent.width
                            height: parent.rowH
                            radius: Services.Sizes.innerR
                            color: Services.Colors.ghost
                            gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                            y: {
                                for (let i = 0; i < win.categories.length; i++)
                                    if (win.activeId === win.categories[i].id)
                                        return i * (parent.rowH + parent.gap)
                                return 0
                            }
                            Behavior on y { SmoothedAnimation { duration: Services.Sizes.msPronounced } }
                        }

                        Column {
                            anchors.fill: parent
                            spacing: parent.gap

                            Repeater {
                                model: win.categories

                                delegate: Item {
                                    id: railItem
                                    required property var modelData
                                    readonly property bool active: win.activeId === modelData.id
                                    width: parent.width
                                    height: 36

                                    readonly property color fg: railItem.active
                                        ? Services.Colors.accentText
                                        : (railHover.containsMouse ? Services.Colors.snow
                                                                   : Services.Colors.mist)

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: railItem.modelData.icon
                                            color: railItem.fg
                                            font.pixelSize: 16
                                            font.family: "Material Symbols Rounded"
                                            Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: railItem.modelData.label
                                            color: railItem.fg
                                            font.pixelSize: Services.Sizes.fsBody
                                            font.bold: true
                                            font.family: "JetBrainsMono NF"
                                            Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                                        }
                                    }

                                    MouseArea {
                                        id: railHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Services.AppState.settingsTab = railItem.modelData.id
                                    }
                                }
                            }
                        }
                    }

                    // ── Right: the section itself ──────────────────────
                    // The rail runs down the side, so a section leaves upwards
                    // or downwards, whichever way you moved along it.
                    Widgets.SlideSwap {
                        id: sectionSlide
                        axis: "vertical"
                        index: win.tabIndex
                        onCommit: tabLoader.source = win.tabSource(Services.AppState.settingsTab)
                    }

                    Loader {
                        id: tabLoader
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        opacity: sectionSlide.fade
                        transform: Translate { y: sectionSlide.offY }
                        Component.onCompleted: source = win.tabSource(Services.AppState.settingsTab)
                        onStatusChanged: if (status === Loader.Error)
                            console.warn("[SettingsPanel] ERROR loading", source)
                    }
                }
            }
        }
    }
}
