import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services

PanelWindow {
    id: win
    anchors { top: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitWidth: 360
    visible: Services.Notifications.activePopups.length > 0

    // The surface spans the full right edge but only the toast column should grab
    // the pointer — otherwise the invisible rest of the window eats clicks meant
    // for the bar pills underneath. Mask input to the cards' region.
    mask: Region { item: col }

    function formatTime(ts) {
        if (!ts) return ""
        return Qt.formatTime(new Date(ts), "hh:mm")
    }

    Column {
        id: col
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 64
        anchors.rightMargin: 12
        spacing: 8
        width: 340

        move: Transition {
            NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: Services.Notifications.activePopups

            delegate: Rectangle {
                id: card
                required property var modelData
                property bool isSystem: modelData.source === "system"
                property bool dismissing: false
                property bool appeared: false
                width: 340
                height: isSystem ? 64 : (bodyTxt.visible ? 88 : 64)
                radius: 14
                color: Services.Colors.surfaceAlpha(0.96)
                border.color: Services.Colors.ghostAlpha(0.2)
                border.width: 0
                clip: true

                opacity: (appeared && !dismissing) ? 1 : 0
                scale: dismissing ? 0.9 : 1
                Component.onCompleted: card.appeared = true
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 200 } }

                transform: Translate {
                    id: slideT
                    x: 24
                    Component.onCompleted: slideT.x = 0
                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }

                function dismiss() {
                    if (card.dismissing) return
                    card.dismissing = true
                    removeTimer.start()
                }

                Timer {
                    id: removeTimer
                    interval: 200
                    onTriggered: Services.Notifications.dismissPopup(modelData.id)
                }

                Timer {
                    interval: card.isSystem ? 1800 : 6000
                    running: true
                    onTriggered: card.dismiss()
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.dismiss()
                }

                // ── Sistema: caja de icono ilustrativo + dos lineas (encabezado + mensaje) ──
                RowLayout {
                    visible: card.isSystem
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Rectangle {
                        width: 38; height: 38
                        radius: 9
                        color: Services.Colors.ghostAlpha(0.15)
                        border.color: Services.Colors.ghostAlpha(0.3)
                        border.width: 0
                        Text {
                            anchors.centerIn: parent
                            text: modelData.glyph || ""
                            color: Services.Colors.ghost
                            font.pixelSize: modelData.glyphIsLetter ? 17 : 18
                            font.bold: modelData.glyphIsLetter === true
                            font.family: modelData.glyphIsLetter ? "JetBrainsMono NF" : "Material Symbols Rounded"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: modelData.summary || "SYSTEM ALERT"
                            color: Services.Colors.ash
                            font.pixelSize: 9
                            font.family: "JetBrainsMono NF"
                            font.letterSpacing: 1
                        }
                        Text {
                            text: modelData.body || ""
                            color: Services.Colors.snow
                            font.pixelSize: 13
                            font.bold: true
                            font.family: "JetBrainsMono NF"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        width: 22; height: 22; radius: 7
                        color: "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: Services.Colors.ash
                            font.pixelSize: 12
                            font.family: "Material Symbols Rounded"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.dismiss()
                        }
                    }
                }

                // ── Apps: icono, titulo, cuerpo ──
                RowLayout {
                    visible: !card.isSystem
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Rectangle {
                        width: 34; height: 34
                        radius: 10
                        color: Services.Colors.ghostAlpha(0.15)
                        Image {
                            id: toastIconImg
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
                            visible: toastIconImg.status !== Image.Ready
                            text: ""
                            color: Services.Colors.ghost
                            font.pixelSize: 16
                            font.family: "Material Symbols Rounded"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

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
                            text: modelData.summary || ""
                            color: Services.Colors.mist
                            font.pixelSize: 11
                            font.family: "JetBrainsMono NF"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            id: bodyTxt
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
                        width: 22; height: 22; radius: 7
                        color: "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: Services.Colors.ash
                            font.pixelSize: 12
                            font.family: "Material Symbols Rounded"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.dismiss()
                        }
                    }
                }
            }
        }
    }
}
