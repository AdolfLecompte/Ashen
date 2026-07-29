import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/services" as Services

Scope {
    id: root

    PanelWindow {
    id: win
    anchors { top: true; left: true; right: true; bottom: true }
    screen: Services.Screens.active
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stays mapped through the close animation, so the exit plays in reverse
    readonly property bool shown: Services.AppState.notificationsVisible
    visible: shown || closeDelay.running
    onShownChanged: if (!shown) closeDelay.restart()
    Timer { id: closeDelay; interval: 300 }

    // Clearing the history fades the list out first, then wipes the model once
    // the fade has played -- otherwise the rows just blink out of existence.
    property bool clearing: false
    Timer {
        id: clearTimer
        interval: 260
        onTriggered: { Services.Notifications.clearAll(); win.clearing = false }
    }
    function fadeClear() {
        if (Services.Notifications.history.length === 0 || win.clearing) return
        win.clearing = true
        clearTimer.restart()
    }

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
        anchors.bottom: parent.bottom
        // Follows the bell: right-hand bar puts its pills on the right edge
        anchors.topMargin: Services.Sizes.marginTop
        anchors.bottomMargin: Services.Sizes.marginBottom
        // Sits on the same side as the bell it belongs to
        x: Services.Sizes.barPosition === "right"
           ? parent.width - width - Services.Sizes.marginRight
           : Services.Sizes.marginLeft
        width: 400
        radius: 18
        color: Services.Colors.surfaceAlpha(0.96)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 0
        clip: true

        // Origin-anchored open: grows out of the LEFT side (mid-height, not a
        // corner) so it reads as sliding open from the edge + fades.
        property real openAmt: Services.AppState.notificationsVisible ? 1.0 : 0.0
        Behavior on openAmt { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

        opacity: Services.AppState.notificationsVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: Scale {
            origin.x: Services.Sizes.barPosition === "right" ? card.width : 0
            origin.y: card.height / 2
            xScale: 0.55 + 0.45 * card.openAmt
            yScale: 0.55 + 0.45 * card.openAmt
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
                        text: "\ue16c"
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
                        onClicked: win.fadeClear()
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

                opacity: win.clearing ? 0.0 : 1.0
                Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

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
                                id: appIconImg
                                anchors.fill: parent
                                anchors.margins: 5
                                // Already resolved to a usable source by
                                // Notifications.resolveIcon (image://, file:// or http).
                                source: modelData.icon || ""
                                sourceSize.width: 48
                                sourceSize.height: 48
                                fillMode: Image.PreserveAspectFit
                                visible: status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: appIconImg.status !== Image.Ready
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
