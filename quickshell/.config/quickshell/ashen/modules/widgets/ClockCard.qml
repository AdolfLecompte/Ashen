import QtQuick
import QtQuick.Layouts
import "root:/services" as Services

// Clock, calendar and weather as one card instead of three plates in a row.
//
// Same deal as MediaCard: content only, no background, and the pieces the bar
// pill also shows (time, date, weather glyph, temperature) can be turned into
// laid-out-but-undrawn slots so the panel can fly its own copies in from the
// pill. `pad` is the padding the caller's background is expected to leave.
//
// The three sections are told apart by hairlines rather than by gaps alone —
// with this much in one card, whitespace on its own stops reading as a break.
Item {
    id: root

    // ── Metrics ─────────────────────────────────────────────────────────
    readonly property real clockW: 350
    readonly property real weatherW: 320
    readonly property real gap: 24
    readonly property real pad: 20
    readonly property real contentW: 1080
    readonly property real contentH: 350

    implicitWidth: contentW
    implicitHeight: contentH
    width: implicitWidth
    height: implicitHeight

    // ── Morph support ───────────────────────────────────────────────────
    property bool ghostShared: false
    readonly property real sharedOpacity: ghostShared ? 0 : 1
    property real extrasOpacity: 1

    // ── Clock ───────────────────────────────────────────────────────────
    // One formatted string, exactly the pill's, so the two can be the same
    // object growing rather than two different clocks crossfading.
    property string timeText: Qt.formatDateTime(new Date(), Services.Prefs.timeFormat)
    property string dateText: Qt.formatDateTime(new Date(), "dddd, MMMM d")
    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            let d = new Date()
            root.now = d
            root.timeText = Qt.formatDateTime(d, Services.Prefs.timeFormat)
            root.dateText = Qt.formatDateTime(d, "dddd, MMMM d")
        }
    }

    // The column always reserves room for the longest clock there is: twelve
    // hour, with seconds and a meridiem. Sizing the type to *that* and centring
    // it means the digits are as large as they can ever be, and changing the
    // format moves nothing — a shorter string just sits in the same box.
    Text {
        id: probe
        visible: false
        text: "00:00:00 AM"
        font.pixelSize: 100
        font.bold: true
        font.family: "JetBrainsMono NF"
    }
    readonly property real clockPx: Math.max(20,
        Math.floor(100 * (clockW - 30) / Math.max(1, probe.width)))

    // ── Where the shared pieces sit, in this item's coordinates ─────────
    readonly property real timeCX: row.x + clockCol.x + head.x + timeT.x + timeT.width / 2
    readonly property real timeCY: row.y + clockCol.y + head.y + timeT.y + timeT.height / 2
    readonly property real dateCX: row.x + clockCol.x + head.x + dateT.x + dateT.width / 2
    readonly property real dateCY: row.y + clockCol.y + head.y + dateT.y + dateT.height / 2
    readonly property real wIconCX: row.x + wxCol.x + wxNow.x + wIcon.x + wIcon.width / 2
    readonly property real wIconCY: row.y + wxCol.y + wxNow.y + wIcon.y + wIcon.height / 2
    readonly property real wTempCX: row.x + wxCol.x + wxNow.x + wTemp.x + wTemp.width / 2
    readonly property real wTempCY: row.y + wxCol.y + wxNow.y + wTemp.y + wTemp.height / 2

    // Which tool is showing under the clock
    property int tab: 0

    // The days after today, and the span they cover. Every day's bar is drawn
    // against this shared range — that is the whole point of the bars: you see
    // which day is the warm one without reading a single number.
    readonly property var fcDays: Services.Weather.forecast.slice(1)
    readonly property int fcMin: {
        let m = 999
        for (let d of fcDays) if (d.minC < m) m = d.minC
        return m === 999 ? 0 : m
    }
    readonly property int fcMax: {
        let m = -999
        for (let d of fcDays) if (d.maxC > m) m = d.maxC
        return m === -999 ? 0 : m
    }

    // ── Inline components ───────────────────────────────────────────────
    // These must be declared on the document's root object; nested inside a
    // Column they simply do not parse.

    // The hairline between sections. Thin, dim, and the only thing doing the
    // separating — no boxes, no fills.
    component VRule: Rectangle {
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        color: Services.Colors.ghostAlpha(0.09)
    }

    component Fact: Row {
        property string glyph: ""
        property string label: ""
        property string value: ""
        spacing: 10
        Text {
            text: parent.glyph
            color: Services.Colors.ghost
            font.pixelSize: 15
            font.family: "Material Symbols Rounded"
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: parent.label
            color: Services.Colors.ash
            font.pixelSize: 11
            font.family: "JetBrainsMono NF"
            anchors.verticalCenter: parent.verticalCenter
            width: 62
        }
        Text {
            text: parent.value
            color: Services.Colors.snow
            font.pixelSize: 12
            font.bold: true
            font.family: "JetBrainsMono NF"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // 270° dial, open at the bottom — the same instrument the process panel
    // uses for CPU, so the shell reads as one kit rather than a pile of
    // one-off widgets.
    component Gauge: Column {
        id: gauge
        property real value: 0
        property real limit: 100
        property string glyph: ""
        property string readout: ""
        property string caption: ""
        spacing: 5

        onValueChanged: dial.requestPaint()

        Item {
            width: 74
            height: 74
            anchors.horizontalCenter: parent.horizontalCenter

            Canvas {
                id: dial
                anchors.fill: parent
                onPaint: {
                    let ctx = getContext("2d")
                    ctx.reset()
                    let cx = width / 2, cy = height / 2
                    let r = (Math.min(width, height) - 10) / 2
                    let a0 = Math.PI * 0.75
                    let sweep = Math.PI * 1.5
                    ctx.lineCap = "round"
                    ctx.lineWidth = 8
                    ctx.strokeStyle = Services.Colors.ghostAlpha(0.12)
                    ctx.beginPath(); ctx.arc(cx, cy, r, a0, a0 + sweep); ctx.stroke()
                    let frac = Math.max(0, Math.min(1, gauge.value / gauge.limit))
                    if (frac > 0) {
                        ctx.strokeStyle = Services.Colors.ghost
                        ctx.beginPath(); ctx.arc(cx, cy, r, a0, a0 + sweep * frac); ctx.stroke()
                    }
                }
                Component.onCompleted: requestPaint()
                Connections {
                    target: Services.Colors
                    function onGhostChanged() { dial.requestPaint() }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 0
                Text {
                    text: gauge.glyph
                    color: Services.Colors.ghost
                    font.pixelSize: 14
                    font.family: "Material Symbols Rounded"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: gauge.readout
                    color: Services.Colors.snow
                    font.pixelSize: 13
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        Text {
            text: gauge.caption
            color: Services.Colors.mist
            font.pixelSize: 9
            font.family: "JetBrainsMono NF"
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // Tools swap by dissolving through each other rather than blinking.
    component Tool: Item {
        property int index: 0
        anchors.fill: parent
        opacity: root.tab === index ? root.extrasOpacity : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: root.gap

        // ── Left: the clock, and the tools that belong to a clock ───────
        Item {
            id: clockCol
            Layout.preferredWidth: root.clockW
            Layout.fillHeight: true

            Column {
                id: head
                anchors.top: parent.top
                width: parent.width
                spacing: 2

                Text {
                    id: timeT
                    opacity: root.sharedOpacity
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.timeText
                    color: Services.Colors.snow
                    font.pixelSize: root.clockPx
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
                Text {
                    id: dateT
                    opacity: root.sharedOpacity
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.dateText
                    color: Services.Colors.mist
                    font.pixelSize: 13
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
            }

            Rectangle {
                id: headRule
                anchors.top: head.bottom
                anchors.topMargin: 20
                width: parent.width
                height: 1
                color: Services.Colors.ghostAlpha(0.09)
                opacity: root.extrasOpacity
            }

            // Category strip: one container pill holding the mode pills, the
            // whole thing centred under the clock it belongs to.
            Item {
                id: tabsWrap
                anchors.top: headRule.bottom
                anchors.topMargin: 20
                width: parent.width
                height: 34
                opacity: root.extrasOpacity
                property Item activeTab: null

                Rectangle {
                    id: tabsPill
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: tabs.width + 8
                    height: 34
                    radius: 12
                    color: Services.Colors.surfaceAlpha(0.82)

                    // Sliding highlight behind whichever pill is picked
                    Rectangle {
                        visible: tabsWrap.activeTab !== null
                        x: 4 + (tabsWrap.activeTab ? tabsWrap.activeTab.x : 0)
                        width: tabsWrap.activeTab ? tabsWrap.activeTab.width : 0
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 9
                        color: Services.Colors.ghost
                        gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                        Behavior on x { SmoothedAnimation { duration: 250 } }
                        Behavior on width { SmoothedAnimation { duration: 220 } }
                    }

                    Row {
                        id: tabs
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        spacing: 4

                        Repeater {
                            model: [
                                { id: 0, label: "Clock",     icon: "" },
                                { id: 1, label: "Stopwatch", icon: "" },
                                { id: 2, label: "Timer",     icon: "" }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: root.tab === modelData.id
                                onActiveChanged: if (active) tabsWrap.activeTab = this
                                Component.onCompleted: if (active) tabsWrap.activeTab = this

                                height: 26
                                width: tabRow.implicitWidth + 18
                                radius: 9
                                // Only the sliding indicator carries the active
                                // fill; idle pills are bare and just brighten.
                                color: active ? "transparent"
                                    : tabHover.containsMouse ? Services.Colors.ghostAlpha(0.12) : "transparent"
                                Behavior on color { ColorAnimation { duration: 140 } }

                                Row {
                                    id: tabRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: parent.parent.modelData.icon
                                        color: parent.parent.active ? Services.Colors.abyss : Services.Colors.snow
                                        font.pixelSize: 13
                                        font.family: "Material Symbols Rounded"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: parent.parent.modelData.label
                                        color: parent.parent.active ? Services.Colors.abyss : Services.Colors.snow
                                        font.pixelSize: 11
                                        font.bold: parent.parent.active
                                        font.family: "JetBrainsMono NF"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: tabHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.tab = parent.modelData.id
                                }
                            }
                        }
                    }
                }
            }

            // ── Tool area: all three stacked, one showing ───────────────
            Item {
                id: tools
                anchors.top: tabsWrap.bottom
                anchors.topMargin: 24
                anchors.bottom: parent.bottom
                width: parent.width

                // -- Clock: what the date actually tells you --
                Tool {
                    index: 0
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        spacing: 10

                        Fact {
                            glyph: ""
                            label: "WEEK"
                            value: {
                                // ISO week: the Thursday of this week owns the year
                                let d = new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate())
                                d.setDate(d.getDate() + 3 - ((d.getDay() + 6) % 7))
                                let jan4 = new Date(d.getFullYear(), 0, 4)
                                let n = 1 + Math.round(((d - jan4) / 86400000
                                        - 3 + ((jan4.getDay() + 6) % 7)) / 7)
                                return String(n)
                            }
                        }
                        Fact {
                            glyph: ""
                            label: "DAY"
                            value: {
                                let start = new Date(root.now.getFullYear(), 0, 0)
                                let n = Math.floor((root.now - start) / 86400000)
                                return n + " of " + (root.isLeap ? 366 : 365)
                            }
                        }
                        Fact {
                            glyph: ""
                            label: "SUNRISE"
                            value: Services.Weather.sunrise || "—"
                        }
                        Fact {
                            glyph: ""
                            label: "SUNSET"
                            value: Services.Weather.sunset || "—"
                        }
                    }
                }

                // -- Stopwatch --
                Tool {
                    index: 1
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        spacing: 12

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Services.Stopwatch.display
                            color: Services.Colors.snow
                            font.pixelSize: 34
                            font.bold: true
                            font.family: "JetBrainsMono NF"
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8
                            CtlChip {
                                glyph: Services.Stopwatch.running ? "" : ""
                                active: Services.Stopwatch.running
                                onTriggered: Services.Stopwatch.toggle()
                            }
                            CtlChip {
                                glyph: ""
                                available: Services.Stopwatch.running
                                onTriggered: Services.Stopwatch.lap()
                            }
                            CtlChip {
                                glyph: ""
                                available: !Services.Stopwatch.idle
                                onTriggered: Services.Stopwatch.reset()
                            }
                        }

                        // Newest first: the lap you just took is the one you
                        // want to read.
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3
                            Repeater {
                                model: Services.Stopwatch.laps.slice(-4).reverse()
                                delegate: Row {
                                    required property var modelData
                                    spacing: 10
                                    Text {
                                        text: "#" + modelData.index
                                        color: Services.Colors.ash
                                        font.pixelSize: 10
                                        font.family: "JetBrainsMono NF"
                                        width: 26
                                    }
                                    Text {
                                        text: Services.Stopwatch.format(modelData.split)
                                        color: Services.Colors.snow
                                        font.pixelSize: 11
                                        font.bold: true
                                        font.family: "JetBrainsMono NF"
                                        width: 76
                                    }
                                    Text {
                                        text: Services.Stopwatch.format(modelData.total)
                                        color: Services.Colors.mist
                                        font.pixelSize: 10
                                        font.family: "JetBrainsMono NF"
                                    }
                                }
                            }
                        }
                    }
                }

                // -- Countdown --
                Tool {
                    index: 2
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        spacing: 12

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Services.Countdown.display
                            color: Services.Countdown.running ? Services.Colors.snow : Services.Colors.mist
                            font.pixelSize: 34
                            font.bold: true
                            font.family: "JetBrainsMono NF"
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        // Drains left to right as it runs down
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 200
                            height: 4
                            radius: 2
                            color: Services.Colors.ghostAlpha(0.15)
                            Rectangle {
                                width: parent.width * Services.Countdown.progress
                                height: parent.height
                                radius: 2
                                color: Services.Colors.ghost
                                gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6
                            Repeater {
                                model: [1, 5, 10, 25]
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool picked: Services.Countdown.preset === modelData * 60000
                                    width: 40; height: 24; radius: 8
                                    color: picked ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.15)
                                    gradient: Services.Prefs.useGradients && picked ? Services.Colors.accentGradient : null
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData + "m"
                                        color: parent.picked ? Services.Colors.abyss : Services.Colors.snow
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: "JetBrainsMono NF"
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Services.Countdown.startFor(modelData * 60000)
                                    }
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8
                            CtlChip {
                                glyph: Services.Countdown.running ? "" : ""
                                active: Services.Countdown.running
                                available: Services.Countdown.remaining > 0
                                onTriggered: Services.Countdown.toggle()
                            }
                            CtlChip {
                                glyph: ""
                                onTriggered: Services.Countdown.bump(-60000)
                            }
                            CtlChip {
                                glyph: ""
                                onTriggered: Services.Countdown.bump(60000)
                            }
                            CtlChip {
                                glyph: ""
                                available: Services.Countdown.active
                                onTriggered: Services.Countdown.reset()
                            }
                        }
                    }
                }
            }
        }

        VRule { opacity: root.extrasOpacity }

        // ── Middle: calendar ────────────────────────────────────────────
        Item {
            id: calCol
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: root.extrasOpacity

            Column {
                id: calStack
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 12

                // Month on the left, controls gathered on the right, so the
                // label and the buttons stop competing for the middle.
                Item {
                    width: parent.width
                    height: 26

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.locale().monthName(grid.curMonth) + " " + grid.curYear
                        color: Services.Colors.snow
                        font.pixelSize: 14
                        font.family: "JetBrainsMono NF"
                        font.bold: true
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        // Same chip as the media transport, so every small
                        // button in the shell behaves identically. Today sits
                        // between the arrows because that is where it belongs:
                        // it is the middle of what they move you away from.
                        CtlChip {
                            glyph: "\ue5cb"
                            size: 28
                            glyphSize: 17
                            onTriggered: {
                                if (grid.curMonth === 0) { grid.curMonth = 11; grid.curYear-- }
                                else grid.curMonth--
                            }
                        }
                        CtlChip {
                            glyph: "\ue8df"
                            size: 28
                            glyphSize: 15
                            // Lit while you are already looking at this month
                            active: grid.curMonth === grid.todayMonth && grid.curYear === grid.todayYear
                            onTriggered: { grid.curMonth = grid.todayMonth; grid.curYear = grid.todayYear }
                        }
                        CtlChip {
                            glyph: "\ue5cc"
                            size: 28
                            glyphSize: 17
                            onTriggered: {
                                if (grid.curMonth === 11) { grid.curMonth = 0; grid.curYear++ }
                                else grid.curMonth++
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    Repeater {
                        model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                        Text {
                            width: calStack.width / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: Services.Colors.ash
                            font.pixelSize: 11
                            font.family: "JetBrainsMono NF"
                        }
                    }
                }

                Grid {
                    id: grid
                    width: parent.width
                    columns: 7
                    spacing: 3

                    // fixed cell size + a reserved height of 6 rows, so a
                    // 5-week month does not shift the column
                    readonly property int cellSize: Math.min(calStack.width / 7 - 3, 34)
                    height: 6 * cellSize + 5 * spacing

                    property int curMonth: new Date().getMonth()
                    property int curYear: new Date().getFullYear()
                    readonly property int today: root.now.getDate()
                    readonly property int todayMonth: root.now.getMonth()
                    readonly property int todayYear: root.now.getFullYear()
                    readonly property int firstDay: new Date(curYear, curMonth, 1).getDay()
                    readonly property int daysInMonth: new Date(curYear, curMonth + 1, 0).getDate()

                    Repeater {
                        model: grid.firstDay + grid.daysInMonth
                        delegate: Rectangle {
                            required property int index
                            readonly property int day: index - grid.firstDay + 1
                            readonly property bool isValid: index >= grid.firstDay
                            readonly property bool isToday: isValid && day === grid.today
                                && grid.curMonth === grid.todayMonth && grid.curYear === grid.todayYear

                            width: calStack.width / 7 - 3
                            height: grid.cellSize
                            radius: 8
                            color: isToday ? Services.Colors.ghost
                                : dayHover.containsMouse && isValid ? Services.Colors.ghostAlpha(0.15)
                                : "transparent"
                            gradient: Services.Prefs.useGradients && isToday ? Services.Colors.accentGradient : null
                            Behavior on color { ColorAnimation { duration: 140 } }

                            Text {
                                anchors.centerIn: parent
                                text: parent.isValid ? parent.day : ""
                                color: parent.isToday ? Services.Colors.abyss : Services.Colors.snow
                                font.pixelSize: 12
                                font.family: "JetBrainsMono NF"
                                font.bold: parent.isToday
                            }

                            MouseArea {
                                id: dayHover
                                anchors.fill: parent
                                hoverEnabled: parent.isValid
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }
        }

        VRule { opacity: root.extrasOpacity }

        // ── Right: weather ──────────────────────────────────────────────
        Item {
            id: wxCol
            Layout.preferredWidth: root.weatherW
            Layout.fillHeight: true

            // Conditions now. The glyph and the number are shared with the bar
            // pill, so they are slots here and fly in from it.
            Item {
                id: wxNow
                anchors.top: parent.top
                width: parent.width
                height: 76

                Text {
                    id: wIcon
                    opacity: root.sharedOpacity
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: Services.Weather.icon
                    color: Services.Colors.neutral
                    font.pixelSize: 48
                    font.family: "Material Symbols Rounded"
                }
                Text {
                    id: wTemp
                    opacity: root.sharedOpacity
                    anchors.left: wIcon.right
                    anchors.leftMargin: 12
                    anchors.top: parent.top
                    anchors.topMargin: 2
                    text: Services.Weather.temp
                    color: Services.Colors.snow
                    font.pixelSize: 30
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
                Column {
                    anchors.left: wIcon.right
                    anchors.leftMargin: 12
                    anchors.top: wTemp.bottom
                    anchors.topMargin: 2
                    spacing: 1
                    opacity: root.extrasOpacity
                    Text {
                        text: Services.Weather.condition
                        color: Services.Colors.mist
                        font.pixelSize: 11
                        font.family: "JetBrainsMono NF"
                    }
                    Text {
                        text: Services.Weather.city
                        color: Services.Colors.ash
                        font.pixelSize: 10
                        font.family: "JetBrainsMono NF"
                    }
                }
            }

            Column {
                id: wxRest
                anchors.top: wxNow.bottom
                anchors.topMargin: 16
                width: parent.width
                spacing: 20
                opacity: root.extrasOpacity

                Row {
                    id: gaugeRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                        Gauge {
                            glyph: ""
                            value: Services.Weather.humidity
                            limit: 100
                            readout: Services.Weather.humidity + "%"
                            caption: "HUMIDITY"
                        }
                        Gauge {
                            // -10..45 °C covers anywhere anyone lives. The dial
                            // is a sense of where in that range today sits; the
                            // number is the fact.
                            glyph: ""
                            value: Services.Weather.tempC + 10
                            limit: 55
                            readout: Services.Weather.temp
                            caption: "TEMP"
                        }
                        Gauge {
                            // 60 km/h is a gale: past that the dial pins and
                            // the number carries the detail anyway
                            glyph: ""
                            value: Services.Weather.windKph
                            limit: 60
                            readout: String(Services.Weather.windKph)
                        caption: "WIND " + Services.Weather.windCompass(Services.Weather.windDir)
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Services.Colors.ghostAlpha(0.09)
                }

                Column {
                    id: fcCol
                    width: parent.width
                    spacing: 7

                        Repeater {
                            model: root.fcDays
                            delegate: Item {
                                required property var modelData
                                readonly property real span: Math.max(1, root.fcMax - root.fcMin)
                                readonly property real lo: (modelData.minC - root.fcMin) / span
                                readonly property real hi: (modelData.maxC - root.fcMin) / span
                                width: parent.width
                                height: 20

                                Text {
                                    id: dLabel
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 32
                                    text: modelData.label
                                    color: Services.Colors.mist
                                    font.pixelSize: 11
                                    font.family: "JetBrainsMono NF"
                                }
                                Text {
                                    id: dIcon
                                    anchors.left: dLabel.right
                                    anchors.leftMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    color: Services.Colors.neutral
                                    font.pixelSize: 15
                                    font.family: "Material Symbols Rounded"
                                }
                                Text {
                                    id: dMin
                                    anchors.left: dIcon.right
                                    anchors.leftMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 28
                                    horizontalAlignment: Text.AlignRight
                                    text: Services.Weather.degrees(modelData.minC)
                                    color: Services.Colors.ash
                                    font.pixelSize: 11
                                    font.family: "JetBrainsMono NF"
                                }
                                // Where this day's low..high falls inside the
                                // whole week's range — the warm day is the one
                                // whose bar sits furthest right, no reading
                                // required.
                                Rectangle {
                                    anchors.left: dMin.right
                                    anchors.leftMargin: 8
                                    anchors.right: dMax.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 4
                                    radius: 2
                                    color: Services.Colors.ghostAlpha(0.12)

                                    Rectangle {
                                        x: parent.width * parent.parent.lo
                                        width: Math.max(4, parent.width * (parent.parent.hi - parent.parent.lo))
                                        height: parent.height
                                        radius: 2
                                        color: Services.Colors.ghost
                                        gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                                    }
                                }
                                Text {
                                    id: dMax
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 28
                                    horizontalAlignment: Text.AlignRight
                                    text: Services.Weather.degrees(modelData.maxC)
                                    color: Services.Colors.snow
                                    font.bold: true
                                    font.pixelSize: 11
                                    font.family: "JetBrainsMono NF"
                                }
                            }
                        }
                    }
                }
            }
        }

    readonly property bool isLeap: {
        let y = now.getFullYear()
        return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0
    }
}
