pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "root:/services" as Services

Singleton {
    id: root
    property string condition: ""
    property int tempC: 0
    property string icon: ""
    property var forecast: []

    // wttr.in only ever gives celsius, so F/K are derived here and every
    // consumer renders through tempString()/degrees() -- never tempC directly.
    function convert(c) {
        if (Services.Prefs.tempUnit === "F") return Math.round(c * 9 / 5 + 32)
        if (Services.Prefs.tempUnit === "K") return Math.round(c + 273.15)
        return Math.round(c)
    }
    // Kelvin is an absolute scale: writing "273°K" is wrong, it has no degree sign
    readonly property string unitSuffix: Services.Prefs.tempUnit === "K" ? "K" : "°" + Services.Prefs.tempUnit
    function tempString(c) { return convert(c) + unitSuffix }
    // Bare number + degree glyph, for the "24°/12°" forecast pairs
    function degrees(c) { return convert(c) + (Services.Prefs.tempUnit === "K" ? "" : "°") }

    readonly property string temp: tempString(tempC)

    function iconFor(cond, hour) {
        let c = (cond || "").toLowerCase()
        let night = hour < 6 || hour >= 19
        if (c.indexOf("thunder") !== -1) return "\uebdb"
        if (c.indexOf("snow") !== -1 || c.indexOf("ice") !== -1 || c.indexOf("blizzard") !== -1) return "\ueb3b"
        if (c.indexOf("rain") !== -1 || c.indexOf("drizzle") !== -1) return "\uf176"
        if (c.indexOf("fog") !== -1 || c.indexOf("mist") !== -1 || c.indexOf("haze") !== -1) return "\ue818"
        if (c.indexOf("storm") !== -1) return "\uf070"
        if (c.indexOf("partly") !== -1) return night ? "\uf174" : "\uf172"
        if (c.indexOf("cloud") !== -1 || c.indexOf("overcast") !== -1) return "\uf15c"
        if (c.indexOf("sunny") !== -1) return "\ue81a"
        if (c.indexOf("clear") !== -1) return night ? "\uf159" : "\uf157"
        return "\uf60b"
    }

    function dayLabel(dateStr, index) {
        if (index === 0) return "Today"
        let d = new Date(dateStr)
        return Qt.locale().dayName(d.getDay(), Locale.ShortFormat)
    }

    Process {
        id: weatherProc
        command: ["sh", "-c", "curl -s --max-time 10 'wttr.in/?format=j1'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text)
                    let cur = data.current_condition[0]
                    root.condition = cur.weatherDesc[0].value
                    root.tempC = parseInt(cur.temp_C)
                    root.icon = root.iconFor(root.condition, new Date().getHours())

                    let days = []
                    for (let i = 0; i < data.weather.length; i++) {
                        let w = data.weather[i]
                        // ~midday slot to represent the day (index 4 of 8 three-hour slots)
                        let midday = w.hourly[Math.min(4, w.hourly.length - 1)]
                        days.push({
                            label: root.dayLabel(w.date, i),
                            maxC: parseInt(w.maxtempC),
                            minC: parseInt(w.mintempC),
                            icon: root.iconFor(midday.weatherDesc[0].value, 12)
                        })
                    }
                    root.forecast = days
                } catch (e) {
                    console.log("[Weather] error parseando:", e)
                }
            }
        }
    }

    Component.onCompleted: weatherProc.running = true

    Timer {
        interval: 900000
        running: true
        repeat: true
        onTriggered: weatherProc.running = true
    }
}
