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
    readonly property real weatherW: 330
    readonly property real gap: 24
    readonly property real pad: 20
    readonly property real contentW: 1100
    readonly property real contentH: 360

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

    // A weather fact on one line: its icon and its number, nothing else.
    component WxFact: Row {
        property string glyph: ""
        property string value: ""
        spacing: 4
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.glyph
            color: Services.Colors.ghost
            font.pixelSize: 13
            font.family: "Material Symbols Rounded"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.value
            color: Services.Colors.mist
            font.pixelSize: 11
            font.family: "JetBrainsMono NF"
        }
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
    // One fact, in a small card: icon and value on a line, its name under it.
    component Stat: Rectangle {
        id: stat
        property string glyph: ""
        property string value: ""
        property string caption: ""
        radius: Services.Sizes.cardR
        color: Services.Colors.fillInset

        Column {
            anchors.centerIn: parent
            spacing: 2

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: stat.glyph
                    color: Services.Colors.ghost
                    font.pixelSize: 15
                    font.family: "Material Symbols Rounded"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: stat.value
                    color: Services.Colors.snow
                    font.pixelSize: 15
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: stat.caption
                color: Services.Colors.mist
                font.pixelSize: 8
                font.family: "JetBrainsMono NF"
            }
        }
    }

    component Gauge: Column {
        id: gauge
        onValueChanged: dial.requestPaint()
        property real value: 0
        property real limit: 100
        property string glyph: ""
        property string readout: ""
        property string caption: ""
        spacing: 5

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

    // Tools slide aside in the direction you moved along the tabs.
    SlideSwap {
        id: toolSlide
        axis: "horizontal"
        index: root.tab
        onCommit: root.shownTool = root.tab
    }
    property int shownTool: 0

    component Tool: Item {
        property int index: 0
        anchors.fill: parent
        opacity: root.shownTool === index ? root.extrasOpacity * toolSlide.fade : 0
        visible: opacity > 0.01
        transform: Translate { x: toolSlide.offX }
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
                    color: Services.Colors.surfacePill

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
                        Behavior on x { SmoothedAnimation { duration: Services.Sizes.msPronounced } }
                        Behavior on width { SmoothedAnimation { duration: Services.Sizes.msStandard } }
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
                                Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

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
                            Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
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
                                    Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
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
                        spacing: Services.Sizes.btnGap

                        // Same chip as the media transport, so every small
                        // button in the shell behaves identically. Today sits
                        // between the arrows because that is where it belongs:
                        // it is the middle of what they move you away from.
                        CtlChip {
                            glyph: "\ue5cb"
                            size: 28
                            glyphSize: 17
                            onTriggered: grid.monthIndex--
                        }
                        CtlChip {
                            glyph: "\ue8df"
                            size: 28
                            glyphSize: 15
                            // Lit while you are already looking at this month
                            active: grid.curMonth === grid.todayMonth && grid.curYear === grid.todayYear
                            onTriggered: grid.monthIndex = grid.todayYear * 12 + grid.todayMonth
                        }
                        CtlChip {
                            glyph: "\ue5cc"
                            size: 28
                            glyphSize: 17
                            onTriggered: grid.monthIndex++
                        }
                    }
                }

                SlideSwap {
                    id: monthSlide
                    axis: "horizontal"
                    travel: 34
                    index: grid.monthIndex
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

                    // ONE property moves the calendar. It used to be month and
                    // year, and stepping past December changed both -- two
                    // changes, so the slide ran twice for one press.
                    property int monthIndex: new Date().getFullYear() * 12 + new Date().getMonth()
                    // The days slide the way the arrow points.
                    opacity: monthSlide.fade
                    transform: Translate { x: monthSlide.offX }

                    readonly property int curMonth: monthIndex % 12
                    readonly property int curYear: Math.floor(monthIndex / 12)
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
                            Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

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
        // City, the reading, three facts on one line, and the days. Nothing
        // else: the hour-by-hour strip made this the loudest column on a card
        // that is mostly a clock.
        Item {
            id: wxCol
            Layout.preferredWidth: root.weatherW
            Layout.fillHeight: true

            // Conditions now: the glyph and the number are shared with the bar
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

            // Humidity, temperature and wind, each in its own dial.
            Row {
                id: gaugeRow
                anchors.top: wxNow.bottom
                anchors.topMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                opacity: root.extrasOpacity

                Gauge {
                    glyph: "\ue798"
                    value: Services.Weather.humidity
                    limit: 100
                    readout: Services.Weather.humidity + "%"
                    caption: "HUMIDITY"
                }
                Gauge {
                    // -10..45 °C covers anywhere anyone lives: the dial is a
                    // sense of where in that range today sits, the number is
                    // the fact.
                    glyph: "\ue1ff"
                    value: Services.Weather.tempC + 10
                    limit: 55
                    readout: Services.Weather.temp
                    caption: "TEMP"
                }
                Gauge {
                    // 60 km/h is a gale: past that the dial pins and the number
                    // carries the detail anyway.
                    glyph: "\uefd8"
                    value: Services.Weather.windKph
                    limit: 60
                    readout: String(Services.Weather.windKph)
                    caption: "WIND " + Services.Weather.windCompass(Services.Weather.windDir)
                }
            }

            // The days, as cards. The one thing on this column worth a box.
            Row {
                id: fcCol
                anchors.top: gaugeRow.bottom
                anchors.topMargin: 16
                anchors.left: parent.left
                anchors.right: parent.right
                height: 92
                spacing: 8
                opacity: root.extrasOpacity

                Repeater {
                    model: root.fcDays

                    delegate: Rectangle {
                        required property var modelData
                        width: (fcCol.width - fcCol.spacing * (root.fcDays.length - 1))
                               / Math.max(1, root.fcDays.length)
                        height: fcCol.height
                        radius: Services.Sizes.cardR
                        color: Services.Colors.fillInset

                        Column {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label.toUpperCase()
                                color: Services.Colors.mist
                                font.pixelSize: 9
                                font.bold: true
                                font.family: "JetBrainsMono NF"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                color: Services.Colors.ghost
                                font.pixelSize: 20
                                font.family: "Material Symbols Rounded"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Services.Weather.degrees(modelData.maxC)
                                color: Services.Colors.snow
                                font.pixelSize: 14
                                font.bold: true
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
