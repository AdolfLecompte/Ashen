import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/services" as Services

Scope {
    id: root

    IpcHandler {
        target: "notifications"
        function toggle() {
            Services.AppState.notificationsVisible = !Services.AppState.notificationsVisible
        }
        function screenshot() {
            Services.Notifications.addSystemToast("SCREENSHOT SAVED", "\uf727", false, "screenshot")
        }
    }

    PanelWindow {
    id: win
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stays mapped through the close animation, so the exit plays in reverse
    readonly property bool shown: Services.AppState.notificationsVisible
    visible: shown || closeDelay.running
    onShownChanged: if (!shown) closeDelay.restart()
    Timer { id: closeDelay; interval: 300 }

    function formatTime(ts) {
        if (!ts) return ""
        return Qt.formatDateTime(new Date(ts), "MMM d, hh:mm")
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.notificationsVisible = false
    }

    FocusScope {
        anchors.fill: parent
        focus: win.shown
        Keys.onEscapePressed: Services.AppState.notificationsVisible = false
    }

    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.topMargin: 64
        anchors.bottomMargin: 12
        anchors.leftMargin: 12
        width: 400
        radius: 18
        color: Services.Colors.surfaceAlpha(0.96)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 0
        clip: true

        opacity: Services.AppState.notificationsVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        transform: Translate {
            x: Services.AppState.notificationsVisible ? 0 : -24
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: ""
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                    color: Services.Colors.ghost
                }
                Text {
                    text: "Notifications"
                    color: Services.Colors.snow
                    font.pixelSize: 15
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                    Layout.fillWidth: true
                    leftPadding: 8
                }
                Rectangle {
                    width: 30; height: 30; radius: 8
                    color: Services.AppState.doNotDisturb ? Services.Colors.ghostAlpha(0.3) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: Services.AppState.doNotDisturb ? "" : ""
                        color: Services.AppState.doNotDisturb ? Services.Colors.ghost : Services.Colors.mist
                        font.pixelSize: 16
                        font.family: "Material Symbols Rounded"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.color = Services.AppState.doNotDisturb ? Services.Colors.ghostAlpha(0.45) : Services.Colors.ghostAlpha(0.15)
                        onExited: parent.color = Services.AppState.doNotDisturb ? Services.Colors.ghostAlpha(0.3) : "transparent"
                        onClicked: Services.AppState.doNotDisturb = !Services.AppState.doNotDisturb
                    }
                }
                Rectangle {
                    width: 30; height: 30; radius: 8
                    color: "transparent"
                    visible: Services.Notifications.history.length > 0
                    Text {
                        anchors.centerIn: parent
                        text: ""
                        color: Services.Colors.mist
                        font.pixelSize: 16
                        font.family: "Material Symbols Rounded"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.color = Services.Colors.ghostAlpha(0.15)
                        onExited: parent.color = "transparent"
                        onClicked: Services.Notifications.clearAll()
                    }
                }
                Rectangle {
                    width: 30; height: 30; radius: 8
                    color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: ""
                        color: Services.Colors.mist
                        font.pixelSize: 16
                        font.family: "Material Symbols Rounded"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.color = Services.Colors.ghostAlpha(0.15)
                        onExited: parent.color = "transparent"
                        onClicked: Services.AppState.notificationsVisible = false
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Services.Colors.ghostAlpha(0.15) }

            Text {
                visible: Services.Notifications.history.length === 0
                text: "No notifications yet"
                color: Services.Colors.ash
                font.pixelSize: 12
                font.family: "JetBrainsMono NF"
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 40
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: Services.Notifications.history

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 4
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    property bool isSystem: modelData.source === "system"
                    width: ListView.view.width
                    height: isSystem ? 40 : (bodyText.visible ? 82 : 60)
                    radius: 10
                    color: isSystem ? "transparent" : Services.Colors.ghostAlpha(0.08)

                    // ── System notifications: subtle, one line, no icon ──
                    RowLayout {
                        visible: parent.isSystem
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: modelData.summary || ""
                            color: Services.Colors.mist
                            font.pixelSize: 11
                            font.family: "JetBrainsMono NF"
                        }
                        Text {
                            text: modelData.body || ""
                            color: Services.Colors.ash
                            font.pixelSize: 11
                            font.family: "JetBrainsMono NF"
                            Layout.fillWidth: true
                        }
                        Text {
                            text: win.formatTime(modelData.timestamp)
                            color: Services.Colors.ash
                            font.pixelSize: 9
                            font.family: "JetBrainsMono NF"
                        }
                    }

                    // ── Third-party app notifications: icon, title, full body ──
                    RowLayout {
                        visible: !parent.isSystem
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Rectangle {
                            width: 34; height: 34
                            radius: 10
                            color: Services.Colors.ghostAlpha(0.15)
                            Image {
                                anchors.fill: parent
                                anchors.margins: 5
                                source: {
                                if ((modelData.icon || "") !== "") {
                                    return modelData.icon.startsWith("/") ? ("file://" + modelData.icon) : Quickshell.iconPath(modelData.icon, 48)
                                }
                                // No explicit icon in the D-Bus hint: guess it from the
                                // lowercased app name (that is how Papirus
                                // suele nombrar sus iconos: whatsapp.svg, discord.svg, steam.svg, etc)
                                if ((modelData.appName || "") !== "") {
                                    return Quickshell.iconPath(modelData.appName.toLowerCase().replace(/\s+/g, "-"), 48)
                                }
                                return ""
                            }
                                fillMode: Image.PreserveAspectFit
                                visible: status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: (modelData.icon || "") === ""
                                text: ""
                                color: Services.Colors.ghost
                                font.pixelSize: 16
                                font.family: "Material Symbols Rounded"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    text: modelData.appName || "Unknown"
                                    color: Services.Colors.snow
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: win.formatTime(modelData.timestamp)
                                    color: Services.Colors.ash
                                    font.pixelSize: 9
                                    font.family: "JetBrainsMono NF"
                                }
                            }
                            Text {
                                text: modelData.summary || ""
                                color: Services.Colors.mist
                                font.pixelSize: 11
                                font.family: "JetBrainsMono NF"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                id: bodyText
                                visible: (modelData.body || "") !== ""
                                text: modelData.body || ""
                                color: Services.Colors.ash
                                font.pixelSize: 10
                                font.family: "JetBrainsMono NF"
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            width: 26; height: 26; radius: 8
                            color: "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: ""
                                color: Services.Colors.ash
                                font.pixelSize: 14
                                font.family: "Material Symbols Rounded"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.color = Services.Colors.ghostAlpha(0.15)
                                onExited: parent.color = "transparent"
                                onClicked: Services.Notifications.removeAt(index)
                            }
                        }
                    }
                }
            }
        }
    }
}
}
