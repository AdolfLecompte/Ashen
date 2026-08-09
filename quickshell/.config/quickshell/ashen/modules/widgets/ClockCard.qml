import QtQuick
import QtQuick.Layouts
import "root:/services" as Services

// Clock, calendar and weather as one card. Content only, no background: `pad`
// is what the caller's plate is expected to leave. The pieces the bar pill also
// shows can be left laid out but undrawn, as targets for the panel's morph.
Item {
    id: root

    // ── Metrics ─────────────────────────────────────────────────────────
    readonly property real clockW: 350
    readonly property real weatherW: 330
    readonly property real gap: 24
    readonly property real pad: 20
    readonly property real contentW: 1100
    // Hugs the tallest column, which is the timer: header 184 + the wheels and
    // their two rows. Any slack past that piles up as dead space at the bottom --
    // the columns are anchored to the top, not spread down the card.
    readonly property real contentH: 400

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

    // How far through the day it is -- what is left of the light is measured
    // against it. Off `now`, so it ticks with everything else on this card
    // rather than keeping a clock of its own.
    readonly property real dayFrac:
        (now.getHours() * 3600 + now.getMinutes() * 60 + now.getSeconds()) / 86400

    // The next 24 hours and the span they cover. The curve is drawn against
    // THIS range, not against absolute degrees: a day between 14° and 19° on a
    // 0..40 chart is a straight line that tells you nothing.
    readonly property var hours: Services.Weather.hourly || []
    readonly property int hourMin: {
        let m = 999
        for (const h of hours) if (h.tempC < m) m = h.tempC
        return m === 999 ? 0 : m
    }
    readonly property int hourMax: {
        let m = -999
        for (const h of hours) if (h.tempC > m) m = h.tempC
        return m === -999 ? 0 : m
    }

    // Every third hour of the strip: which sample it is, what it read, and the
    // time on it. Eight stamps across 24 hours -- one an hour is a smear.
    readonly property var marks3h: {
        const out = []
        for (let i = 0; i < hours.length; i += 3)
            out.push({ i: i, t: hours[i].tempC, label: root.shortHour(hours[i].label) })
        return out
    }
    // The clock under the chart goes every SIX hours: eight stamps of
    // "12:00 AM" ran into each other across 330 px.
    readonly property var marks6h: {
        const out = []
        for (let i = 0; i < hours.length; i += 6)
            out.push({ i: i, label: root.shortHour(hours[i].label) })
        return out
    }
    // "3:00 PM" -> "3PM", "15:00" -> "15". On an axis the minutes are always
    // :00 and saying so eight times is just wider.
    function shortHour(s) {
        if (!s) return ""
        const t = String(s)
        const ap = t.indexOf("PM") >= 0 ? "PM" : (t.indexOf("AM") >= 0 ? "AM" : "")
        return t.split(":")[0] + ap
    }

    // Aim the countdown without starting it. A second is the floor: the wheels
    // can be spun to 00:00:00, and a timer of no length is not a thing to hand
    // to a service that would just refuse it and leave the wheels lying.
    function aimAt(ms) { Services.Countdown.setPreset(Math.max(1000, ms)) }

    // The quickest lap taken so far, so the strip can point at it.
    readonly property real bestSplit: {
        let b = -1
        for (const l of Services.Stopwatch.laps)
            if (b < 0 || l.split < b) b = l.split
        return b
    }

    // "HH:MM" as a fraction of the day, or -1 for anything that is not one.
    // The sun times arrive with the forecast and are empty until it lands.
    // The sun times come from Weather.clockOf, which formats for READING -- so
    // in 12-hour mode this gets "6:12 PM", and taking the 6 at face value put
    // sunset before lunch and the ring into the wrong half of its day.
    function hhmmFrac(s) {
        if (!s || s.length < 4) return -1
        const t = String(s).trim()
        const p = t.split(":")
        let h = parseInt(p[0])
        const m = parseInt(p[1])
        if (isNaN(h) || isNaN(m)) return -1
        if (t.indexOf("PM") >= 0 && h < 12) h += 12
        if (t.indexOf("AM") >= 0 && h === 12) h = 0
        return (h * 3600 + m * 60) / 86400
    }

    // What the middle of the day ring says: how much light is left, or how long
    // until it comes back. A number nobody else on the card is already giving.
    readonly property real sunUpFrac: hhmmFrac(Services.Weather.sunrise)
    readonly property real sunDownFrac: hhmmFrac(Services.Weather.sunset)
    function spanText(frac) {
        const mins = Math.max(0, Math.round(frac * 1440))
        const h = Math.floor(mins / 60), m = mins % 60
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }
    readonly property string daylightLeft: {
        if (sunUpFrac < 0 || sunDownFrac < 0) return "—"
        if (dayFrac < sunUpFrac) return spanText(sunUpFrac - dayFrac)
        if (dayFrac < sunDownFrac) return spanText(sunDownFrac - dayFrac)
        return spanText(1 - dayFrac + sunUpFrac)
    }
    readonly property string daylightCaption: {
        if (sunUpFrac < 0 || sunDownFrac < 0) return ""
        if (dayFrac < sunUpFrac) return "UNTIL SUNRISE"
        if (dayFrac < sunDownFrac) return "OF LIGHT LEFT"
        return "UNTIL SUNRISE"
    }

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

    // One fact of the day: a plain centered row -- glyph, name, number. No
    // plate and no rule; the list is four lines, it does not need furniture.
    component Fact: Row {
        property string glyph: ""
        property string label: ""
        property string value: ""
        spacing: 12
        Text {
            text: parent.glyph
            color: Services.Colors.ghost
            font.pixelSize: 16
            font.family: "Material Symbols Rounded"
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: parent.label
            color: Services.Colors.ash
            font.pixelSize: 11
            font.bold: true
            font.family: "JetBrainsMono NF"
            anchors.verticalCenter: parent.verticalCenter
            width: 92
        }
        Text {
            text: parent.value
            color: Services.Colors.snow
            font.pixelSize: 13
            font.bold: true
            font.family: "JetBrainsMono NF"
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            width: 78
        }
    }

    // One column of a hh:mm:ss picker. A ListView with its highlight range
    // nailed to the middle row IS a wheel -- no Controls dependency and no
    // hand-rolled flicking. Nothing here reads `preset` as a binding: the wheel
    // both follows it and writes it, so the follow has to be an assignment that
    // can be switched off while it is the one doing the writing.
    component Wheel: Item {
        id: wheel
        property int count: 60
        property int unitMs: 1000
        readonly property int rowH: 38
        // What this column's digits are worth in the current preset.
        readonly property int value: Math.floor(Services.Countdown.preset / unitMs) % count
        property bool syncing: false
        // Nothing this wheel does counts as an instruction until a hand has
        // moved it. A ListView settles its own currentIndex once it has a
        // geometry, well after Component.onCompleted -- three wheels each
        // reporting that settle as a choice is what turned a fresh 5-minute
        // preset into 01:01:01.
        property bool touched: false

        width: 66
        height: rowH * 3

        // Setting currentIndex is enough: StrictlyEnforceRange already drags the
        // view onto it. Calling positionViewAtIndex as well made the two fight
        // and land a row off -- three wheels each one step out is where a fresh
        // 5-minute preset came up as 01:01:01.
        function sync() {
            if (view.moving || view.dragging) return
            wheel.syncing = true
            view.currentIndex = wheel.value
            wheel.syncing = false
        }
        Component.onCompleted: wheel.sync()
        Connections {
            target: Services.Countdown
            function onPresetChanged() { wheel.sync() }
        }

        ListView {
            id: view
            anchors.fill: parent
            clip: true
            model: wheel.count
            orientation: ListView.Vertical
            snapMode: ListView.SnapToItem
            // The selected row is the middle one, always.
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: wheel.rowH
            preferredHighlightEnd: wheel.rowH * 2
            boundsBehavior: Flickable.StopAtBounds

            onMovementStarted: wheel.touched = true
            onCurrentIndexChanged: {
                if (wheel.syncing || !wheel.touched) return
                const cur = Services.Countdown.preset
                const mine = Math.floor(cur / wheel.unitMs) % wheel.count
                if (view.currentIndex === mine) return
                root.aimAt(cur + (view.currentIndex - mine) * wheel.unitMs)
            }

            delegate: Item {
                required property int index
                width: wheel.width
                height: wheel.rowH
                readonly property bool sel: index === view.currentIndex
                Text {
                    anchors.centerIn: parent
                    text: (parent.index < 10 ? "0" : "") + parent.index
                    color: parent.sel ? Services.Colors.snow : Services.Colors.ash
                    opacity: parent.sel ? 1 : 0.55
                    font.pixelSize: parent.sel ? 34 : 24
                    font.bold: parent.sel
                    font.family: "JetBrainsMono NF"
                    Behavior on font.pixelSize { NumberAnimation { duration: Services.Sizes.msMicro } }
                    Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }
                }
            }
        }
    }

    component WheelColon: Text {
        width: 14
        height: 114
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: ":"
        color: Services.Colors.mist
        font.pixelSize: 30
        font.bold: true
        font.family: "JetBrainsMono NF"
    }

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
                                        color: parent.parent.active ? Services.Colors.accentText : Services.Colors.snow
                                        font.pixelSize: 13
                                        font.family: "Material Symbols Rounded"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: parent.parent.modelData.label
                                        color: parent.parent.active ? Services.Colors.accentText : Services.Colors.snow
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

                // -- Clock: what today is, in plain rows --
                // No ring, no plates, no rules: a short centred list.
                Tool {
                    index: 0
                    Column {
                        anchors.centerIn: parent
                        spacing: 14

                        // Daylight leads the list -- it is the one reading
                        // nothing else on the card gives.
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 12
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Services.Weather.icon
                                color: Services.Colors.ghost
                                font.pixelSize: 20
                                font.family: "Material Symbols Rounded"
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text {
                                    text: root.daylightLeft
                                    color: Services.Colors.snow
                                    font.pixelSize: 18
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                }
                                Text {
                                    text: root.daylightCaption
                                    color: Services.Colors.mist
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                }
                            }
                        }

                        Fact {
                            anchors.horizontalCenter: parent.horizontalCenter
                            glyph: ""
                            label: "SUNRISE"
                            value: Services.Weather.sunrise || "—"
                        }
                        Fact {
                            anchors.horizontalCenter: parent.horizontalCenter
                            glyph: ""
                            label: "SUNSET"
                            value: Services.Weather.sunset || "—"
                        }
                        Fact {
                            anchors.horizontalCenter: parent.horizontalCenter
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
                            anchors.horizontalCenter: parent.horizontalCenter
                            glyph: ""
                            label: "DAY of " + (root.isLeap ? "366" : "365")
                            value: {
                                let start = new Date(root.now.getFullYear(), 0, 0)
                                return String(Math.floor((root.now - start) / 86400000))
                            }
                        }
                    }
                }

                // -- Stopwatch: the number, and nothing around it --
                // It had a ring for a while. A stopwatch has no end to be a
                // fraction of, so the ring was drawing a minute nobody asked
                // about while the digits -- the whole point -- had to shrink to
                // fit inside it.
                Tool {
                    index: 1
                    Column {
                        anchors.centerIn: parent
                        spacing: 20

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Services.Stopwatch.display
                            color: Services.Colors.snow
                            font.pixelSize: 46
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

                        // Newest on the left, the fastest one wearing the accent:
                        // which lap was the good one is a comparison, and a
                        // column of bare numbers never makes it for you.
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6
                            Repeater {
                                model: Services.Stopwatch.laps.slice(-4).reverse()
                                delegate: Rectangle {
                                    required property var modelData
                                    // Nothing is "fastest" until there is
                                    // something to be faster than.
                                    readonly property bool best: Services.Stopwatch.laps.length > 1
                                        && modelData.split === root.bestSplit
                                    width: 60
                                    height: 34
                                    radius: Services.Sizes.innerR
                                    color: best ? Services.Colors.ghost : Services.Colors.fillInset
                                    gradient: Services.Prefs.useGradients && best
                                        ? Services.Colors.accentGradient : null
                                    Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 0
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "#" + modelData.index
                                            color: parent.parent.best ? Services.Colors.accentBody : Services.Colors.ash
                                            font.pixelSize: 9
                                            font.family: "JetBrainsMono NF"
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: Services.Stopwatch.format(modelData.split)
                                            color: parent.parent.best ? Services.Colors.accentText : Services.Colors.snow
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.family: "JetBrainsMono NF"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // -- Countdown: pick the time on the wheels, or take a preset --
                Tool {
                    index: 2
                    Column {
                        anchors.centerIn: parent
                        spacing: 18

                        // Two faces, one slot: the wheels are for setting, and
                        // once it is counting the only thing worth the space is
                        // what is left.
                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: wheels.width
                            height: 114

                            Row {
                                id: wheels
                                anchors.centerIn: parent
                                spacing: 2
                                opacity: Services.Countdown.active ? 0 : 1
                                visible: opacity > 0.01
                                Behavior on opacity { NumberAnimation { duration: Services.Sizes.msStandard } }

                                Wheel { id: wHours;   count: 24; unitMs: 3600000 }
                                WheelColon { }
                                Wheel { id: wMins;    count: 60; unitMs: 60000 }
                                WheelColon { }
                                Wheel { id: wSecs;    count: 60; unitMs: 1000 }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Services.Countdown.display
                                color: Services.Countdown.running ? Services.Colors.snow : Services.Colors.mist
                                font.pixelSize: 46
                                font.bold: true
                                font.family: "JetBrainsMono NF"
                                opacity: Services.Countdown.active ? 1 : 0
                                visible: opacity > 0.01
                                Behavior on opacity { NumberAnimation { duration: Services.Sizes.msStandard } }
                                Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
                            }
                        }

                        // The lengths worth a button; the wheels cover everything
                        // between them.
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6
                            Repeater {
                                model: [1, 5, 10, 25]
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool picked: Services.Countdown.preset === modelData * 60000
                                    width: 42; height: 24; radius: 8
                                    color: picked ? Services.Colors.ghost : Services.Colors.fillInset
                                    gradient: Services.Prefs.useGradients && picked
                                        ? Services.Colors.accentGradient : null
                                    Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData + "m"
                                        color: parent.picked ? Services.Colors.accentText : Services.Colors.snow
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: "JetBrainsMono NF"
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        // A length aims the timer; starting is
                                        // the one button that starts things.
                                        onClicked: root.aimAt(modelData * 60000)
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

                    // The name rides the SAME slide as the days. It already
                    // reads off `shownIndex`, so it changed at the commit --
                    // correct, but as a cut, next to a grid that travels.
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.locale().monthName(grid.curMonth) + " " + grid.curYear
                        color: Services.Colors.snow
                        font.pixelSize: 14
                        font.family: "JetBrainsMono NF"
                        font.bold: true
                        opacity: monthSlide.fade
                        transform: Translate { x: monthSlide.offX }
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
                            // Lit while you are already looking at this month.
                            // Off `monthIndex`, not the month on show: a button
                            // answers when you press it, not a slide later.
                            active: grid.monthIndex === grid.todayYear * 12 + grid.todayMonth
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
                    onCommit: grid.shownIndex = grid.monthIndex
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
                    // The month the days are drawn from, following `monthIndex` on the slide's
                    // commit so the grid changes off screen. Assigned, never bound: a binding
                    // would track the month live and the days would change on the press.
                    property int shownIndex: 0
                    Component.onCompleted: grid.shownIndex = grid.monthIndex
                    // The days slide the way the arrow points.
                    opacity: monthSlide.fade
                    transform: Translate { x: monthSlide.offX }

                    readonly property int curMonth: shownIndex % 12
                    readonly property int curYear: Math.floor(shownIndex / 12)
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
                                color: parent.isToday ? Services.Colors.accentText : Services.Colors.snow
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

            // The three figures, as figures. They used to be three dials, and
            // a dial that says "62%" next to the number 62% is drawing the same
            // sentence twice.
            Row {
                id: wxFacts
                anchors.top: wxNow.bottom
                anchors.topMargin: 10
                anchors.left: parent.left
                spacing: 16
                opacity: root.extrasOpacity

                WxFact { glyph: ""; value: Services.Weather.feels }
                WxFact { glyph: ""; value: Services.Weather.humidity + "%" }
                WxFact {
                    glyph: ""
                    value: Services.Weather.windKph + " "
                         + Services.Weather.windCompass(Services.Weather.windDir)
                }
            }

            // The next 24 hours: the one thing this column can say that no
            // other part of the card already says. The curve is the same Trend
            // the process panel draws, shifted so the coldest hour sits on the
            // floor -- a chart of absolute temperature is a flat line all day.
            Item {
                id: hourly
                anchors.top: wxFacts.bottom
                anchors.topMargin: 14
                anchors.left: parent.left
                anchors.right: parent.right
                height: 88
                opacity: root.extrasOpacity
                visible: root.hours.length > 1

                // The curve, with the temperature written ON it every three
                // hours and the clock under it. A line with no numbers was the
                // complaint and it was the right one: a shape alone says the
                // afternoon is warmer, which anyone already knew.
                Trend {
                    id: curve
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 14
                    height: 46
                    values: {
                        const out = []
                        for (const h of root.hours) out.push(h.tempC - root.hourMin)
                        return out
                    }
                    // Never zero: a day that holds one temperature would divide
                    // the chart by nothing.
                    maxValue: Math.max(1, root.hourMax - root.hourMin)
                }

                // Every third hour gets its degrees, sitting just above where
                // the line actually is -- the same arithmetic Trend uses to
                // place the point, or the number would float off its own curve.
                Repeater {
                    model: root.marks3h
                    delegate: Text {
                        required property var modelData
                        readonly property int span: Math.max(1, root.hours.length - 1)
                        readonly property real fx: hourly.width * modelData.i / span
                        readonly property real fy: {
                            const cap = Math.max(1, root.hourMax - root.hourMin)
                            const f = (modelData.t - root.hourMin) / cap
                            return curve.y + 3 + (curve.height - 6) * (1 - f)
                        }
                        x: Math.max(0, Math.min(hourly.width - width, fx - width / 2))
                        y: fy - height - 2
                        text: Services.Weather.degrees(modelData.t)
                        color: Services.Colors.snow
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "JetBrainsMono NF"
                    }
                }

                // The clock under the curve, every six hours.
                Repeater {
                    model: root.marks6h
                    delegate: Text {
                        required property var modelData
                        readonly property int span: Math.max(1, root.hours.length - 1)
                        x: Math.max(0, Math.min(hourly.width - width,
                                                hourly.width * modelData.i / span - width / 2))
                        anchors.top: curve.bottom
                        anchors.topMargin: 5
                        text: modelData.label
                        color: Services.Colors.ash
                        font.pixelSize: 9
                        font.family: "JetBrainsMono NF"
                    }
                }
            }

            // The days, as cards. The one thing on this column worth a box.
            Row {
                id: fcCol
                anchors.top: hourly.bottom
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
