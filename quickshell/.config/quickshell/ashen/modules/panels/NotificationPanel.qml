import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/modules/widgets" as Widgets
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
    onShownChanged: {
        if (shown) {
            // Picked once per opening: it should have a bit of character
            // without flickering while you look at it.
            win.emptyLine = win.emptyLines[Math.floor(Math.random() * win.emptyLines.length)]
        } else {
            closeDelay.restart()
            // Marked on the way out, not on the way in: while the rail is open
            // the marks still say which ones arrived since you last looked.
            Services.Notifications.markAllRead()
        }
    }
    Timer { id: closeDelay; interval: arrive.holdMs }

    Widgets.PanelArrive {
        id: arrive
        shown: win.shown
    }

    // Nothing to show is not an error, so it does not get an error's voice.
    readonly property var emptyLines: [
        "Nothing over here",
        "All quiet",
        "Lost something?",
        "Not a peep",
        "You're all caught up",
        "Clean slate"
    ]
    property string emptyLine: "All quiet"

    // Clearing the history sweeps the rows out one after another and only then
    // wipes the model -- a whole list blinking out at once reads as a glitch.
    property bool clearing: false
    readonly property int clearStepMs: 45
    Timer {
        id: clearTimer
        onTriggered: { Services.Notifications.clearAll(); win.clearing = false }
    }
    // Rows on their way out. Removing one used to take it out of the model in
    // the same frame the button was pressed, so the sweep that clearing all of
    // them plays never happened for a single row or a single app.
    property var leavingIds: []
    readonly property int rowLeaveMs: 260

    function removeRow(id) {
        if (win.leavingIds.indexOf(id) !== -1) return
        win.leavingIds = win.leavingIds.concat([id])
        rowGone.restart()
    }

    // One timer for the lot: rows marked together leave together, each on its
    // own clearDelay, and the model is only touched once they have all gone.
    Timer {
        id: rowGone
        interval: win.rowLeaveMs + 120
        onTriggered: {
            const ids = win.leavingIds
            win.leavingIds = []
            for (let i = 0; i < ids.length; i++) Services.Notifications.removeById(ids[i])
        }
    }

    function clearGroup(app) {
        const ids = Services.Notifications.history
            .filter(e => Services.Notifications.groupKey(e) === app)
            .map(e => e.id)
        if (ids.length === 0) return
        win.leavingIds = win.leavingIds.concat(ids)
        // Long enough for the last row's turn to have played.
        rowGone.interval = win.rowLeaveMs + 120 + ids.length * win.clearStepMs
        rowGone.restart()
    }

    function fadeClear() {
        if (Services.Notifications.history.length === 0 || win.clearing) return
        win.clearing = true
        clearTimer.interval = Math.min(950, 260 + Services.Notifications.history.length * win.clearStepMs)
        clearTimer.restart()
    }

    // Which app groups are open. A published list, not a map mutated in place:
    // an object assignment notifies nobody and the rows would not re-evaluate.
    property var expandedApps: []
    function toggleGroup(app) {
        if (win.expandedApps.indexOf(app) === -1) win.expandedApps = win.expandedApps.concat([app])
        else win.expandedApps = win.expandedApps.filter(a => a !== app)
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
        // What it becomes. The pill grows into these.
        readonly property int fullW: 400
        readonly property int fullH: parent.height - Services.Sizes.marginTop - Services.Sizes.marginBottom

        // Always on the left, whatever the bar is doing: the place you look
        // for your notifications must not move with an unrelated setting.
        x: arrive.boxX(Services.Sizes.marginLeft, fullW)
        y: arrive.boxY(Services.Sizes.marginTop, fullH)
        width: arrive.boxW(fullW)
        height: arrive.boxH(fullH)
        radius: 20
        color: Services.Colors.surfacePanel
        border.width: 0
        clip: true

        opacity: arrive.fade

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            // Deliberately NOT anchored to the card: it is built at the card's
            // final size and clipped while the pill is still growing. Anchored,
            // every row would reflow on every frame of the growth.
            x: 18
            y: 18
            width: card.fullW - 36
            height: card.fullH - 36
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: Services.Sizes.btnGap
                // Content assembles once the box is in place, each piece a beat
                // behind the last. One driver, no animation per child.
                opacity: arrive.stage(0)
                transform: Translate { y: arrive.riseOf(0) }

                Text {
                    text: "Notifications"
                    color: Services.Colors.snow
                    font.pixelSize: 15
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                    leftPadding: 8
                    rightPadding: 6
                }
                // How many arrived since the rail was last closed.
                Rectangle {
                    visible: Services.Notifications.unreadCount > 0
                    implicitWidth: Math.max(18, unreadTxt.implicitWidth + 10)
                    implicitHeight: 18
                    radius: 9
                    color: Services.Colors.ghost
                    gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                    Text {
                        id: unreadTxt
                        anchors.centerIn: parent
                        text: Services.Notifications.unreadCount
                        color: Services.Colors.accentText
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "JetBrainsMono NF"
                    }
                }
                Item { Layout.fillWidth: true }

                Widgets.IconButton {
                    glyph: Services.AppState.doNotDisturb ? "" : ""
                    active: Services.AppState.doNotDisturb
                    onActivated: Services.AppState.doNotDisturb = !Services.AppState.doNotDisturb
                }
                Widgets.IconButton {
                    // Same glyph as the toast stack's sweep: one idea, one icon.
                    glyph: "\ue0b8"
                    visible: Services.Notifications.history.length > 0
                    onActivated: win.fadeClear()
                }
                Widgets.IconButton {
                    glyph: ""
                    onActivated: Services.AppState.notificationsVisible = false
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Services.Colors.ghostAlpha(0.12)
                opacity: arrive.stage(1)
            }

            // Empty state: a drawn bell rather than a sentence on its own, so
            // the panel does not look broken when there is simply nothing.
            Item {
                visible: Services.Notifications.history.length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                opacity: arrive.stage(2)
                transform: Translate { y: arrive.riseOf(2) }

                // Centred against the card, not stacked with layout alignment:
                // Layout.alignment inside a nested ColumnLayout left the block
                // hanging off to one side.
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 56
                    spacing: 10

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        // done_all: nothing left, everything seen.
                        text: "\ue877"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 42
                        color: Services.Colors.ghostAlpha(0.25)
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.emptyLine
                        color: Services.Colors.mist
                        font.pixelSize: 13
                        font.bold: true
                        font.family: "JetBrainsMono NF"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "whatever shows up lands here"
                        color: Services.Colors.ash
                        font.pixelSize: 10
                        font.family: "JetBrainsMono NF"
                    }
                }
            }

            // One section per app. A chatty app used to bury everything else in
            // a single flat column; now it collapses into its own run.
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: Services.Notifications.history.length > 0
                opacity: arrive.stage(2)
                transform: Translate { y: arrive.riseOf(2) }
                clip: true
                spacing: 12
                model: Services.Notifications.groupedHistory

                // Rows that arrive while the rail is open slide in rather than
                // appearing fully formed at the top of the list.
                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Services.Sizes.easeOut }
                    NumberAnimation { property: "x"; from: -20; to: 0; duration: 320; easing.type: Services.Sizes.easeBox }
                }
                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 280; easing.type: Services.Sizes.easeBox }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 4
                }

                delegate: Column {
                    id: group
                    required property var modelData
                    required property int index
                    readonly property bool many: modelData.items.length > 1
                    readonly property bool open: win.expandedApps.indexOf(modelData.app) !== -1
                    // A single notice needs no section chrome; a run of them
                    // shows the newest until you ask for the rest.
                    readonly property var rows: (!many || open) ? modelData.items : modelData.items.slice(0, 1)
                    width: list.width
                    spacing: 4

                    Item {
                        visible: group.many
                        width: parent.width
                        height: group.many ? 22 : 0

                        Text {
                            id: groupName
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: group.modelData.app.toUpperCase()
                            color: Services.Colors.mist
                            font.pixelSize: 9
                            font.bold: true
                            font.family: "JetBrainsMono NF"
                            font.letterSpacing: 1.4
                        }
                        // The count sits in its own chip so the app name reads
                        // as a label and not as "Discord 3".
                        Rectangle {
                            id: countChip
                            anchors.left: groupName.right
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(16, countTxt.implicitWidth + 8)
                            height: 15
                            radius: 7
                            color: Services.Colors.ghostAlpha(group.modelData.unread > 0 ? 0.4 : 0.16)
                            Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                            Text {
                                id: countTxt
                                anchors.centerIn: parent
                                text: group.modelData.items.length
                                color: Services.Colors.mist
                                font.pixelSize: 9
                                font.bold: true
                                font.family: "JetBrainsMono NF"
                            }
                        }
                        // Hairline out to the controls: ties the label to its
                        // run without drawing a box around it.
                        Rectangle {
                            anchors.left: countChip.right
                            anchors.leftMargin: 10
                            anchors.right: groupCtl.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            height: 1
                            color: Services.Colors.ghostAlpha(0.09)
                        }

                        Row {
                            id: groupCtl
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Services.Sizes.btnGap
                            Widgets.IconButton {
                                size: 24
                                glyph: group.open ? "" : ""
                                onActivated: win.toggleGroup(group.modelData.app)
                            }
                            Widgets.IconButton {
                                size: 24
                                glyph: "\ue0b8"
                                onActivated: win.clearGroup(group.modelData.app)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.rightMargin: 46
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.toggleGroup(group.modelData.app)
                        }
                    }

                    Repeater {
                        model: group.rows
                        delegate: NotifRow {
                            required property var modelData
                            required property int index
                            entry: modelData
                            width: group.width
                            // The sweep runs down the list rather than taking
                            // every row in the same frame.
                            clearDelay: win.clearing ? (group.index * 70) + (index * win.clearStepMs)
                                                     : (index * win.clearStepMs)
                            clearing: win.clearing
                                || win.leavingIds.indexOf(modelData.id) !== -1
                        }
                    }
                }
            }
        }
    }
    }

    // ── Shared pieces ──────────────────────────────────────────────────────
    // Inline components only parse in the document's root object, so they live
    // out here rather than next to where they are used.

    // Declarative hover throughout: assigning `color` in onEntered burns the
    // binding it came from, and these all derive their rest colour from state.
    component NotifRow: Item {
        id: row
        property var entry: ({})
        // Its place in the sweep when everything is being cleared.
        property int clearDelay: 0
        property bool clearing: false

        // Is the pointer anywhere in this row, its buttons included. A child
        // MouseArea takes hover off the one underneath it, so the row cannot
        // ask its own MouseArea: a HoverHandler still sees the pointer while
        // it is over the × or an action button.
        readonly property alias pointed: rowPointer.hovered

        readonly property bool isSystem: entry.source === "system"
        readonly property bool unread: entry.read === false
        // The buttons the sender offered, minus the one the row itself is.
        readonly property var acts: (entry.actions || []).filter(a => a.id !== "default")
        // Only live while the notification behind them is: a stored button has
        // nothing left to press.
        readonly property bool hasActs: acts.length > 0
                                        && Services.Notifications.liveIds.indexOf(entry.id) !== -1

        readonly property int contentH: isSystem ? 38 : (bodyText.visible ? 84 : 62)
        height: contentH + (hasActs ? 38 : 0)
        Behavior on height { NumberAnimation { duration: Services.Sizes.msMicro; easing.type: Services.Sizes.easeOut } }

        // The sweep: each row leaves towards the edge, in its own turn.
        onClearingChanged: if (clearing) sweepOut.start()
        SequentialAnimation {
            id: sweepOut
            PauseAnimation { duration: row.clearDelay }
            ParallelAnimation {
                NumberAnimation { target: plate; property: "opacity"; to: 0; duration: 200; easing.type: Services.Sizes.easeIn }
                NumberAnimation { target: rowSlide; property: "x"; to: -34; duration: 240; easing.type: Services.Sizes.easeIn }
            }
        }

        Rectangle {
            id: plate
            anchors.fill: parent
            radius: 12
            color: row.isSystem ? "transparent"
                                : Services.Colors.ghostAlpha(row.pointed ? 0.14 : 0.08)
            Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
            transform: Translate { id: rowSlide }
            clip: true

            // Clicking a row goes where the notification points, the same as
            // clicking its toast did. It only reported hover before, so a
            // notification you had already let expire was a dead end.
            HoverHandler { id: rowPointer }

            MouseArea {
                id: rowHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: row.isSystem ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: if (!row.isSystem) Services.Notifications.activateFromHistory(row.entry.id)
            }

            // Unread marker: a bar down the leading edge, no extra chrome.
            Rectangle {
                visible: row.unread && !row.isSystem
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 14
                width: 3
                height: row.contentH - 28
                radius: 2
                color: Services.Colors.ghost
            }

            // ── System notices: subtle, one line, no icon ──
            RowLayout {
                visible: row.isSystem
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: row.contentH
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    text: row.entry.summary || ""
                    color: Services.Colors.mist
                    font.pixelSize: 11
                    font.family: "JetBrainsMono NF"
                }
                Text {
                    text: row.entry.body || ""
                    color: Services.Colors.ash
                    font.pixelSize: 11
                    font.family: "JetBrainsMono NF"
                    Layout.fillWidth: true
                }
                Text {
                    text: Services.Notifications.relTime(row.entry.timestamp, Services.Notifications.clockTick)
                    color: Services.Colors.ash
                    font.pixelSize: 9
                    font.family: "JetBrainsMono NF"
                }
            }

            // ── App notices: art, who it is from, what it says ──
            Item {
                visible: !row.isSystem
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                height: row.contentH - 24

                ClippingRectangle {
                    id: artBox
                    width: 34; height: 34
                    radius: 11
                    anchors.top: parent.top
                    color: Services.Colors.ghostAlpha(0.15)
                    Image {
                        id: appIconImg
                        // The notice's own art fills the frame; a bare app icon
                        // is padded, because app icons are drawn to sit on one.
                        readonly property bool isArt: (row.entry.image || "") !== ""
                        anchors.fill: parent
                        anchors.margins: isArt ? 0 : 6
                        source: row.entry.image || row.entry.icon || ""
                        sourceSize.width: 64
                        sourceSize.height: 64
                        fillMode: isArt ? Image.PreserveAspectCrop : Image.PreserveAspectFit
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

                Column {
                    anchors.left: artBox.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 26
                    anchors.top: parent.top
                    spacing: 2

                    Row {
                        width: parent.width
                        spacing: 6
                        Text {
                            width: Math.min(implicitWidth, parent.width - 60)
                            text: (row.entry.appName || "Unknown").toUpperCase()
                            color: Services.Colors.ash
                            font.pixelSize: 8
                            font.family: "JetBrainsMono NF"
                            font.letterSpacing: 1.2
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            width: 2; height: 2; radius: 1
                            anchors.verticalCenter: parent.verticalCenter
                            color: Services.Colors.ash
                        }
                        Text {
                            text: Services.Notifications.relTime(row.entry.timestamp, Services.Notifications.clockTick)
                            color: Services.Colors.ash
                            font.pixelSize: 8
                            font.family: "JetBrainsMono NF"
                        }
                    }
                    Text {
                        width: parent.width
                        text: row.entry.summary || row.entry.appName || ""
                        color: Services.Colors.snow
                        font.pixelSize: 12
                        font.bold: true
                        font.family: "JetBrainsMono NF"
                        elide: Text.ElideRight
                        topPadding: 1
                    }
                    Text {
                        id: bodyText
                        width: parent.width
                        visible: (row.entry.body || "") !== ""
                        text: row.entry.body || ""
                        color: Services.Colors.mist
                        font.pixelSize: 10
                        font.family: "JetBrainsMono NF"
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Only under the pointer: a row of permanent × down the list turns
            // the history into a column of buttons.
            Widgets.IconButton {
                // A system row is a row like any other. With this off, a
                // screenshot toast could only be got rid of by clearing the
                // whole history -- there was no way to dismiss just the one.
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                size: 24
                glyph: ""
                // Its own hover counts too: the button sits ON TOP of the row's
                // MouseArea, so reaching for it took the hover off the row and
                // it faded out from under the pointer. That is what
                // IconButton.hovered is for.
                opacity: row.pointed ? 1 : 0
                // Faded out is not gone: at opacity 0 it still swallowed the
                // clicks in that corner, so the top-right of every row
                // dismissed the notice instead of opening it.
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }
                onActivated: win.removeRow(row.entry.id)
            }

            // Sender-supplied buttons, reachable at last: the server has always
            // advertised actionsSupported, but nothing ever drew them.
            Row {
                visible: row.hasActs
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 56
                anchors.rightMargin: 12
                anchors.bottomMargin: 8
                spacing: 6

                Repeater {
                    model: row.acts.slice(0, 3)
                    delegate: Rectangle {
                        required property var modelData
                        height: 26
                        width: Math.min(130, rowActLabel.implicitWidth + 20)
                        radius: 8
                        color: rowActHover.containsMouse ? Services.Colors.ghostAlpha(0.4)
                                                         : Services.Colors.ghostAlpha(0.16)
                        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                        scale: Services.Sizes.hoverScale(rowActHover.containsMouse, rowActHover.pressed)
                        Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut } }

                        Text {
                            id: rowActLabel
                            anchors.centerIn: parent
                            text: modelData.text || modelData.id
                            color: rowActHover.containsMouse ? Services.Colors.snow : Services.Colors.mist
                            font.pixelSize: 10
                            font.family: "JetBrainsMono NF"
                            elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                        }

                        MouseArea {
                            id: rowActHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.Notifications.invokeAction(row.entry.id, modelData.id)
                        }
                    }
                }
            }
        }
    }
}
