pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property string condition: ""
    property int tempC: 0
    property string icon: ""
    property var forecast: []

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
                        // hora ~del mediodia para representar el dia (indice 4 de 8 tramos de 3h)
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
