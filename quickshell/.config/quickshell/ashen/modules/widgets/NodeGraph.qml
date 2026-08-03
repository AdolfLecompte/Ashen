import QtQuick
import QtQuick.Shapes
import "root:/services" as Services

// A hub with a ring of fixed slots: what you are connected to in the middle,
// what you already know orbiting it. Slots never reshuffle. Strangers live in
// the scan list, not on the ring.
Item {
    id: root

    // ── Hub ─────────────────────────────────────────────────────────────
    property string hubGlyph: ""
    property string hubLabel: ""
    property string hubSub: ""
    property bool hubActive: false

    // ── Ring: [{ id, glyph, label, sub, active }] ───────────────────────
    property var nodes: []
    // Slots the ring can hold. Past this the extras simply are not drawn;
    // the caller decides what deserves a place.
    readonly property int slotCount: 6

    // What to say when the ring has nothing on it: an empty orbit around a lone
    // hub looks broken otherwise.
    property string emptyHint: ""

    // While a panel morphs its bar chip into this hub, the hub lends out its
    // face: the flying copies are the ones on screen until they land.
    property bool handOverFace: false
    property bool handOverGlyph: handOverFace
    property bool handOverLabel: handOverFace
    readonly property alias hubGlyphItem: hubGlyphText
    readonly property alias hubLabelItem: hubLabelText

    // Whether the radio is on. Switching it off pulls the whole ring back into
    // the hub and lets it fall dark; switching it on throws it back out. The
    // ring appearing out of nowhere was the one moment the graph looked like a
    // list that had been rearranged.
    property bool live: true
    property real liveAmt: live ? 1 : 0
    Behavior on liveAmt { NumberAnimation { duration: Services.Sizes.msPanel; easing.type: Services.Sizes.easeBox } }

    // ── Scan ────────────────────────────────────────────────────────────
    // The last slot is always the scan chip. Pressing it takes the middle and
    // fills the ring with strangers, drawn without wires.
    property bool scanEnabled: false
    property string scanGlyph: ""
    property string scanLabel: "Scan"
    property string scanSub: ""
    property var scanNodes: []
    property bool scanMode: false
    // The stranger you asked to join: the wire is drawn to it while whatever
    // asks for the password is on screen.
    property string armedId: ""

    signal nodeActivated(string id)
    signal hubActivated()
    signal scanActivated()
    signal scanNodeActivated(string id)
    signal scanClosed()

    readonly property string scanId: "__scan__"

    function enterScan() {
        beginSwap(scanId)
        scanCommit.restart()
    }
    // Leaves the way it arrived, in reverse.
    function exitScan() {
        armedId = ""
        scanMode = false
        // Republish first: the ring goes back to the known networks with the
        // scan chip in its slot, so the chip has somewhere to ride out to and
        // the others are already where they belong. Then freeze it.
        publishRing()
        if (!ringNodes.slice(0, slotCount).find(x => x && x.id === scanId)) {
            scanClosed()
            return
        }
        pendingLabel = ""
        frozenGlyph = hubGlyph
        frozenLabel = hubLabel
        frozenSub = hubSub
        frozenActive = hubActive
        pendingId = scanId
        // Start where the entrance finished — chip in the middle — without
        // animating into that state, and only then let it travel back out.
        animateSwap = false
        swapAmt = 1
        animateSwap = true
        swapAmt = 0
        exitCommit.restart()
        scanClosed()
    }
    Timer {
        id: exitCommit
        // Just after the chip has settled back into its slot. Until then the
        // graph stays frozen, so a scan landing mid-move cannot renumber the
        // slots under the piece that is still travelling.
        interval: 500
        onTriggered: root.pendingId = ""
    }
    function disarm() { armedId = "" }
    Timer {
        id: scanCommit
        // Lands just after the chip finishes climbing into the middle.
        interval: 430
        onTriggered: {
            root.scanMode = true
            root.endSwap()
        }
    }

    implicitWidth: 650
    implicitHeight: 360

    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real hubR: 62
    // How far out the slot centres sit. Wider than tall: the card is landscape,
    // and the diagonals need horizontal room for their elbow.
    readonly property real ringX: Math.min(width / 2 - 92, 234)
    // The top and bottom slots need room for the node itself AND the run of
    // wire below it; at the old distance both were pinched against the edge.
    readonly property real ringY: Math.min(height / 2 - 44, 140)
    // Diagonal slots drop less than the vertical ones, which need the full
    // radius to clear the hub. Towards 1 = rounder ring, lower = flatter.
    readonly property real diagonalDrop: 0.62

    readonly property real nodeH: 48

    // Filled while it is the hub; once it has shrunk past halfway it is a node
    // like any other and has to be dressed like one, or it lands as a bright
    // slab with dark text on a card full of translucent chips.
    readonly property bool hubFilled: shownActive && swapAmt < 0.5

    // Six slots, evenly spaced but rotated 30° so nothing sits dead above or
    // below the hub, where a connector would have nowhere to bend.
    function slotAngle(i) { return (30 + i * 60) * Math.PI / 180 }
    function slotX(i) { return cx + Math.cos(slotAngle(i)) * ringX * liveAmt }
    function slotY(i) {
        const s = Math.sin(slotAngle(i))
        // Straight up and down keeps the full radius; the diagonals are flattened.
        return cy + s * ringY * (Math.abs(s) < 0.9 ? diagonalDrop : 1) * liveAmt
    }

    // ── Connecting: the swap ────────────────────────────────────────────
    // The node climbs into the middle while the old one rides out to its slot,
    // and holds at "Connecting…" until the radio agrees.
    property string pendingId: ""
    property real swapAmt: 0
    property bool animateSwap: true
    Behavior on swapAmt {
        enabled: root.animateSwap
        NumberAnimation { duration: 480; easing.type: Services.Sizes.easeBox }
    }

    // Frozen while a swap is in flight: the radio drops before it reconnects,
    // and the live data would renumber the slots mid-move.
    property string pendingLabel: ""
    property string frozenGlyph: ""
    property string frozenLabel: ""
    property string frozenSub: ""
    property bool frozenActive: false

    // Slot-indexed, so a hole stays a hole: the scan chip keeps the last slot
    // whether there are four known networks or none, and nothing shuffles
    // under your finger when one comes or goes.
    readonly property var liveRing: {
        const out = []
        const src = scanMode ? scanNodes : nodes
        const room = (scanEnabled && !scanMode) ? slotCount - 1 : slotCount
        for (let i = 0; i < room; i++)
            out.push(i < src.length ? src[i] : null)
        if (scanEnabled && !scanMode)
            out.push({ id: scanId, glyph: scanGlyph, label: scanLabel,
                       sub: scanSub, active: false, kind: "scan" })
        return out
    }
    // PUBLISHED, never derived: handing the Repeater a different array rebuilds
    // every delegate, so it simply stops being republished during a swap.
    property var ringNodes: []
    function publishRing() { if (pendingId === "") ringNodes = liveRing }

    // Which slot the pointer is on, published by the node itself: `itemAt` is
    // not reactive, but an index cannot go stale.
    property int hoveredSlot: -1
    // Bumped whenever the ring gains or loses a node, so the few things that DO
    // still have to ask a delegate for its size go and ask again.
    property int ringRevision: 0
    onLiveRingChanged: publishRing()
    onPendingIdChanged: publishRing()
    Component.onCompleted: publishRing()
    readonly property int ringCount: {
        let n = 0
        for (let i = 0; i < ringNodes.length; i++)
            if (ringNodes[i] && ringNodes[i].kind !== "scan") n++
        return n
    }
    // In scan view the middle IS the scan chip, grown into the hub.
    readonly property string shownGlyph: pendingId !== "" ? frozenGlyph
        : scanMode ? scanGlyph : hubGlyph
    readonly property string shownLabel: pendingId !== "" ? frozenLabel
        : scanMode ? scanLabel : hubLabel
    readonly property string shownSub: pendingId !== "" ? frozenSub
        : scanMode ? scanSub : hubSub
    readonly property bool shownActive: pendingId !== "" ? frozenActive
        : scanMode ? true : hubActive

    readonly property int pendingIndex: {
        for (let i = 0; i < Math.min(ringNodes.length, slotCount); i++)
            if (ringNodes[i] && ringNodes[i].id === pendingId) return i
        return -1
    }

    function beginSwap(id) {
        // Off the published ring, which is what is actually on screen — reading
        // the live one could pick a node the ring has not shown yet.
        const n = ringNodes.slice(0, slotCount).find(x => x && x.id === id)
        if (!n) return
        pendingLabel = n.label
        frozenGlyph = hubGlyph
        frozenLabel = hubLabel
        frozenSub = hubSub
        frozenActive = hubActive
        pendingId = id
        swapAmt = 1
        swapGuard.restart()
    }
    // Snapped back, never animated: by now the bindings draw exactly what the
    // swap was holding, so animating the reset would play the move twice.
    function endSwap() {
        swapGuard.stop()
        pendingLabel = ""
        animateSwap = false
        swapAmt = 0
        pendingId = ""
        animateSwap = true
    }
    // Only the device we asked for ends it. A switch passes through "not
    // connected" on the way, and reacting to that dropped the animation
    // halfway and threw the graph back to live data mid-move.
    onHubLabelChanged: if (pendingId !== "" && hubLabel === pendingLabel) endSwap()
    Timer {
        id: swapGuard
        // A wrong password fails by never connecting, so nothing would ever
        // put the graph back.
        interval: 20000
        onTriggered: root.endSwap()
    }

    // The two swapping pieces travel the same line in opposite directions, so
    // they bow away from it — one to each side — instead of passing through
    // each other in the middle.
    readonly property real pdx: pendingIndex >= 0 ? slotX(pendingIndex) - cx : 0
    readonly property real pdy: pendingIndex >= 0 ? slotY(pendingIndex) - cy : 0
    readonly property real plen: Math.max(1, Math.hypot(pdx, pdy))
    readonly property real bow: Math.sin(Math.PI * swapAmt) * 30
    readonly property real bowX: -pdy / plen * bow
    readonly property real bowY: pdx / plen * bow

    // Only a device rides out to a slot. "Not connected" is not a network: it
    // has no slot to go to and turning it into a node claimed there was one.
    // With nothing connected the middle simply empties as the new one arrives.
    readonly property bool hubTravels: shownActive && pendingIndex >= 0 && pendingId !== scanId
    readonly property real hubAmt: hubTravels ? swapAmt : 0

    // Where the hub is drawn: dead centre normally, riding out to the promoted
    // node's slot while a swap plays.
    readonly property real hubX: cx + pdx * hubAmt + bowX * (hubTravels ? 1 : 0)
    readonly property real hubY: cy + pdy * hubAmt + bowY * (hubTravels ? 1 : 0)
    // ...shrinking from hub to node as it goes, so it lands looking like the
    // node it is about to become — a rounded rectangle, not a lozenge.
    readonly property real hubW: hubR * 2 + (150 - hubR * 2) * hubAmt
    readonly property real hubH: hubR * 2 + (nodeH - hubR * 2) * hubAmt
    readonly property real hubRadius: hubR + (14 - hubR) * hubAmt

    // ── The line ────────────────────────────────────────────────────────
    // One shape for every line on the card: out of the middle, rounded corner,
    // vertical run, corner, arrive at the near side. Never a diagonal.
    component Wire: Shape {
        id: w

        // Where it leaves from, and how far out along the bearing to start.
        // A distance rather than a box, because the middle is a circle for most
        // of its life and a circle's edge is the same in every direction.
        property real fromX: 0
        property real fromY: 0
        property real fromTrim: 0
        // Where it arrives, as centre and half-size: the run comes in at the
        // node's near side, which needs the box, not a radius. On a 150×48 pill
        // a radius stops the line a third of the way inside it.
        property real toX: 0
        property real toY: 0
        property real toHW: 60
        property real toHH: 24
        // Nodes are translucent, so a line that stops under one shows through
        // as a stray dash. It stops short — close enough to read as attached.
        property real gap: 5

        property bool lit: false
        // A line to something already agreed can close up into a solid when you
        // point at it. One to a stranger cannot: nothing has been agreed yet,
        // and a solid line would say it had been. It thickens and brightens
        // instead, and stays dashed.
        property bool solidWhenLit: true

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        z: 0

        readonly property real dx: toX - fromX
        readonly property real dy: toY - fromY
        readonly property real len: Math.max(1, Math.hypot(dx, dy))
        readonly property real x0: fromX + dx / len * fromTrim
        readonly property real y0: fromY + dy / len * fromTrim
        // Straight above or below the middle: there is no near side to speak
        // of, so the run drops into the top or bottom edge instead of setting
        // off sideways and doubling back. Both corners collapse to nothing on
        // their own, so this needs no case of its own further down.
        readonly property bool vertical: Math.abs(dx) < toHW
        readonly property real x1: vertical ? toX : toX - (dx > 0 ? 1 : -1) * (toHW + gap)
        readonly property real y1: vertical ? toY - (dy > 0 ? 1 : -1) * (toHH + gap) : toY
        // Turns halfway between the two, not up against the node, so the elbow
        // reads as a corner rather than a nick in the line.
        readonly property real turnX: vertical ? x1 : x0 + (x1 - x0) * 0.5
        readonly property real r: Math.min(10, Math.abs(turnX - x0), Math.abs(y1 - y0) / 2)
        readonly property real sx: turnX >= x0 ? 1 : -1
        readonly property real sy: y1 >= y0 ? 1 : -1

        // Bare card between the two ends. Callers whose ends move fade the
        // line out on this rather than draw it inside a node.
        readonly property real clearance: len - fromTrim - Math.max(toHW, toHH)

        ShapePath {
            strokeColor: w.lit ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.4)
            strokeWidth: w.lit ? 3.5 : 2.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            // Canvas cannot do this at all — Context2D has no setLineDash —
            // which is why the whole graph is Shapes rather than the Canvas
            // everything else in Ashen draws with.
            strokeStyle: (w.lit && w.solidWhenLit) ? ShapePath.SolidLine : ShapePath.DashLine
            // Dash lengths are multiples of the stroke width, so a thicker line
            // needs a shorter pattern or the dashes turn into bars.
            dashPattern: [2, 2.4]

            Behavior on strokeWidth { NumberAnimation { duration: Services.Sizes.msMicro } }
            Behavior on strokeColor { ColorAnimation { duration: Services.Sizes.msMicro } }

            startX: w.x0
            startY: w.y0
            PathLine { x: w.turnX - w.sx * w.r; y: w.y0 }
            PathQuad {
                controlX: w.turnX; controlY: w.y0
                x: w.turnX; y: w.y0 + w.sy * w.r
            }
            PathLine { x: w.turnX; y: w.y1 - w.sy * w.r }
            PathQuad {
                controlX: w.turnX; controlY: w.y1
                x: w.turnX + (w.x1 >= w.turnX ? 1 : -1) * w.r; y: w.y1
            }
            PathLine { x: w.x1; y: w.y1 }
        }
    }

    // ── Connectors ──────────────────────────────────────────────────────
    // Drawn under everything else. Dashed while idle; the dashes close up into
    // a solid line when you point at the node it belongs to, which is the whole
    // reason the ring reads as connected rather than decorative.
    Repeater {
        model: Math.min(root.ringNodes.length, root.slotCount)

        delegate: Wire {
            id: wire
            required property int index

            // Asked for its SIZE only. Position comes off the slot, which is
            // arithmetic; a delegate from `itemAt` may not be placed yet.
            readonly property Item target: { root.ringRevision; return nodeRepeater.itemAt(index) }
            readonly property bool alive: target !== null && target.width > 1
            readonly property var entry: root.ringNodes[index]
            readonly property bool present: entry !== null && entry !== undefined
            readonly property bool isScan: present && entry.kind === "scan"

            lit: root.hoveredSlot === index
            // Pointing at a stranger, or at the button that goes looking for
            // them, strings a dashed line to it: there is no connection yet,
            // but that is where one would go. It never sets solid — see
            // solidWhenLit — because nothing has been agreed with it.
            solidWhenLit: !isScan && !root.scanMode

            // A known network keeps its line; a stranger only gets one under
            // the pointer, because a line claims a relationship.
            readonly property bool resting: present && !isScan && !root.scanMode
            readonly property bool onHover: present && (isScan || root.scanMode) && lit
            // The elbow only makes sense between a parked middle and a parked
            // slot. While those two are trading places the thread below draws
            // them instead, because two boxes crossing need one line following
            // both, not a corner anchored to where they used to be.
            readonly property bool swapping: root.pendingIndex === index

            opacity: root.liveAmt * (swapping ? 1 - root.swapAmt * 3 : 1)
                   * ((resting || onHover) ? 1 : 0)
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }

            fromX: root.cx
            fromY: root.cy
            fromTrim: root.hubR + 14
            toX: root.slotX(index)
            toY: root.slotY(index)
            toHW: (alive ? target.width : 130) / 2
            toHH: (alive ? target.height : root.nodeH) / 2
        }
    }

    // ── The thread ──────────────────────────────────────────────────────
    // The same elbow with both ends live, following the two pieces as they
    // trade places.
    Wire {
        id: thread
        // Two jobs: the pair trading places, and the stranger you just asked to
        // join — that one has no line of its own, so this is what says "this is
        // the one you picked" while the password is being asked.
        readonly property int armedIndex: {
            if (root.armedId === "") return -1
            for (let i = 0; i < root.ringNodes.length; i++)
                if (root.ringNodes[i] && root.ringNodes[i].id === root.armedId) return i
            return -1
        }
        // Only the armed stranger. During a swap the two pieces touch by 14 %
        // of the move, so no line fits between them anyway.
        readonly property int index: armedIndex
        // Size only, and only if it is a live one. Where the far end IS gets
        // worked out below from the same arithmetic the node itself uses.
        readonly property Item node: {
            root.ringRevision
            return index >= 0 ? nodeRepeater.itemAt(index) : null
        }
        readonly property bool alive: node !== null && node.width > 1
        // Both ends move here, so unlike a ring connector this one can run out
        // of room: it spans the gap while the pieces are apart and steps out of
        // the way as they cross, rather than drawing a line inside them.
        opacity: (index >= 0 && alive && clearance > 6) ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }

        // Neither end has agreed to anything yet — a swap is a request and so
        // is a stranger you have armed — so this one is dashed throughout.
        lit: false
        solidWhenLit: false

        fromX: root.hubX
        fromY: root.hubY
        // The middle is a rounded rectangle by now, not a circle, so how far
        // out to start depends on which way it is being left.
        fromTrim: {
            const hw = root.hubW / 2
            const hh = root.hubH / 2
            const ux = Math.abs(dx) / len
            const uy = Math.abs(dy) / len
            const tx = ux > 0.001 ? hw / ux : 1e9
            const ty = uy > 0.001 ? hh / uy : 1e9
            return Math.min(tx, ty) + 5
        }
        // Straight off the slot: an armed stranger is parked, and a delegate's
        // position may not be settled yet.
        toX: index < 0 ? 0 : root.slotX(index)
        toY: index < 0 ? 0 : root.slotY(index)
        toHW: (alive ? node.width : 130) / 2
        toHH: (alive ? node.height : root.nodeH) / 2
    }

    // ── The hub ─────────────────────────────────────────────────────────
    Rectangle {
        id: hub
        width: root.hubW
        height: root.hubH
        // Interpolated, not derived from the size: `min(w, h) / 2` turned it
        // into a lozenge on the way out, and nothing else on the card is one.
        radius: root.hubRadius
        // With nowhere to go it hands the middle over by clearing out of it.
        opacity: root.hubTravels || root.pendingIndex < 0 ? 1 : 1 - root.swapAmt
        scale: root.hubTravels || root.pendingIndex < 0 ? 1 : 1 - 0.25 * root.swapAmt
        x: root.hubX - width / 2
        y: root.hubY - height / 2
        z: 2
        color: root.hubFilled ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.14)
        gradient: Services.Prefs.useGradients && root.hubFilled ? Services.Colors.accentGradient : null
        Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }

        // A soft ring around it, so the hub reads as the source the wires come
        // out of rather than just the biggest node. It goes with the swap: a
        // halo around something node-shaped looks like a mistake.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 20
            height: parent.height + 20
            radius: width / 2
            color: "transparent"
            border.color: Services.Colors.ghostAlpha(0.14)
            border.width: 1.5
            z: -1
            opacity: 1 - root.swapAmt
        }

        Column {
            anchors.centerIn: parent
            spacing: 2
            // The texts are the first thing to go when the hub shrinks into a
            // node: at half size they no longer fit and reading two labels
            // stacked on each other is worse than reading none.
            opacity: root.hubTravels ? 1 - root.swapAmt * 1.6 : 1
            visible: !root.hubTravels || root.swapAmt < 0.62
            Text {
                id: hubGlyphText
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.shownGlyph
                color: root.hubFilled ? Services.Colors.accentText : Services.Colors.ghost
                font.family: "Material Symbols Rounded"
                font.pixelSize: 30
                // Handed over while a panel is flying its bar chip into this
                // spot: two copies of the same glyph would give the trick away.
                opacity: root.handOverGlyph ? 0 : 1
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                // The circle is round: a label as wide as the diameter runs out
                // over the curve at both ends, which is what was eating it.
                width: root.hubR * 1.72
                horizontalAlignment: Text.AlignHCenter
                id: hubLabelText
                text: root.shownLabel
                color: root.hubFilled ? Services.Colors.accentText : Services.Colors.snow
                opacity: root.handOverLabel ? 0 : 1
                font.pixelSize: 12
                font.bold: true
                font.family: "JetBrainsMono NF"
                elide: Text.ElideRight
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.shownSub !== ""
                text: root.shownSub
                color: root.hubFilled ? Services.Colors.accentText : Services.Colors.mist
                font.pixelSize: 10
                font.family: "JetBrainsMono NF"
                opacity: 0.8
            }
        }

        // The face it wears once it has shrunk to node size. Without this the
        // device leaving the middle arrived at its slot as a blank pill, and
        // the whole point of the swap is watching *what* moved where.
        Row {
            anchors.centerIn: parent
            spacing: 8
            // Both driven off swapAmt directly: reading its own `opacity` back
            // for `visible` left the row dark for the whole swap.
            opacity: root.hubTravels ? Math.max(0, root.swapAmt * 1.8 - 0.8) : 0
            visible: root.hubTravels && root.swapAmt > 0.45

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.shownGlyph
                color: root.hubFilled ? Services.Colors.accentText : Services.Colors.ghost
                font.family: "Material Symbols Rounded"
                font.pixelSize: 18
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    text: root.shownLabel
                    color: root.hubFilled ? Services.Colors.accentText : Services.Colors.snow
                    font.pixelSize: 12
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 118)
                }
                Text {
                    visible: root.shownSub !== ""
                    text: root.shownSub
                    color: root.hubFilled ? Services.Colors.accentText : Services.Colors.ash
                    font.pixelSize: 10
                    font.family: "JetBrainsMono NF"
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: root.swapAmt < 0.01
            // In scan view the middle is the way back out of it.
            onClicked: {
                if (root.scanMode) root.exitScan()
                else root.hubActivated()
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.cy + root.hubR + 30
        visible: root.ringCount === 0 && root.emptyHint !== ""
        text: root.emptyHint
        color: Services.Colors.mist
        font.pixelSize: 11
        font.family: "JetBrainsMono NF"
    }

    // ── The ring ────────────────────────────────────────────────────────
    Repeater {
        id: nodeRepeater
        model: root.ringNodes.slice(0, root.slotCount)

        delegate: Rectangle {
            id: node
            required property int index
            required property var modelData
            property alias hovered: nodeHover.containsMouse

            // Empty slots are holes on purpose: the scan chip has to stay where
            // you left it whether there are four known networks or none.
            readonly property bool empty: !modelData
            visible: !empty
            enabled: !empty

            readonly property bool isScan: !empty && modelData.kind === "scan"
            readonly property bool armed: !empty && root.armedId === modelData.id
            readonly property bool dark: (!empty && modelData.active) || promoting || armed

            // The one being promoted: it climbs to the middle and swells into
            // the hub it is replacing.
            readonly property bool promoting: root.pendingIndex === index
            readonly property real amt: promoting ? root.swapAmt : 0

            readonly property real baseW: Math.max(isScan ? 108 : 120,
                18 + 8 + Math.max(labelT.width, subT.width) + 26)
            width: baseW + (root.hubR * 2 - baseW) * amt
            height: root.nodeH + (root.hubR * 2 - root.nodeH) * amt
            radius: 14 + (root.hubR - 14) * amt
            x: root.slotX(index) + (root.cx - root.slotX(index)) * amt
               - (promoting ? root.bowX : 0) - width / 2
            y: root.slotY(index) + (root.cy - root.slotY(index)) * amt
               - (promoting ? root.bowY : 0) - height / 2
            z: promoting ? 3 : 1

            color: (!empty && modelData.active) || promoting || armed ? Services.Colors.ghost
                 : nodeHover.containsMouse ? Services.Colors.ghostAlpha(0.32)
                 : Services.Colors.ghostAlpha(0.14)
            Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

            // Folded into the hub with the radio off, and it fades on the way
            // rather than sliding under it as a solid block.
            opacity: root.liveAmt

            // Arrives by swelling into its slot, the same entrance the bar
            // pills use when one is added.
            scale: 0
            Component.onCompleted: { scale = 1; root.ringRevision++ }
            Component.onDestruction: {
                root.ringRevision++
                if (root.hoveredSlot === index) root.hoveredSlot = -1
            }
            Behavior on scale { NumberAnimation { duration: Services.Sizes.msPronounced; easing.type: Easing.OutBack; easing.overshoot: Services.Sizes.overshoot } }

            // The halo the hub wears. It fades in as the node becomes the hub,
            // so what lands in the middle is the middle, not a big chip.
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 20
                height: parent.height + 20
                radius: width / 2
                color: "transparent"
                border.color: Services.Colors.ghostAlpha(0.14)
                border.width: 1.5
                z: -1
                opacity: node.amt
                visible: node.amt > 0.02
            }

            // Two faces, same as the hub has: a chip reads left-to-right, the
            // middle reads top-down. Promoting one and leaving it in chip
            // layout put the icon beside the name in a place where every other
            // state has it above.
            Row {
                id: nodeCol
                anchors.centerIn: parent
                spacing: 8
                opacity: 1 - node.amt * 1.8
                visible: node.amt < 0.6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: node.empty ? "" : node.modelData.glyph
                    color: node.dark ? Services.Colors.accentText : Services.Colors.ghost
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        id: labelT
                        text: node.empty ? "" : node.modelData.label
                        color: node.dark ? Services.Colors.accentText : Services.Colors.snow
                        font.pixelSize: 12
                        font.bold: true
                        font.family: "JetBrainsMono NF"
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 118)
                    }
                    Text {
                        id: subT
                        visible: text !== ""
                        text: node.empty ? "" : (node.modelData.sub || "")
                        color: node.dark ? Services.Colors.accentText : Services.Colors.ash
                        font.pixelSize: 10
                        font.family: "JetBrainsMono NF"
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 2
                opacity: Math.max(0, node.amt * 1.8 - 0.8)
                visible: node.amt > 0.45

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: node.empty ? "" : node.modelData.glyph
                    color: Services.Colors.accentText
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 30
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.hubR * 1.72
                    horizontalAlignment: Text.AlignHCenter
                    text: node.empty ? "" : node.modelData.label
                    color: Services.Colors.accentText
                    font.pixelSize: 12
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                    elide: Text.ElideRight
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: node.isScan ? (root.scanSub !== "" ? root.scanSub : "Scanning\u2026")
                                      : "Connecting\u2026"
                    color: Services.Colors.accentText
                    font.pixelSize: 10
                    font.family: "JetBrainsMono NF"
                    opacity: 0.8
                }
            }

            MouseArea {
                id: nodeHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // The node says which slot is under the pointer; the connector
                // reads that index rather than reaching for this item.
                onContainsMouseChanged: {
                    if (containsMouse) root.hoveredSlot = node.index
                    else if (root.hoveredSlot === node.index) root.hoveredSlot = -1
                }
                // One swap at a time, and the ring is not clickable while it is
                // folded away.
                enabled: !node.empty && root.pendingId === "" && root.liveAmt > 0.99
                onClicked: {
                    if (node.isScan) {
                        root.enterScan()
                        root.scanActivated()
                    } else if (root.scanMode) {
                        // A stranger: no swap, nothing has been agreed yet. The
                        // wire is strung to it and whoever is listening puts up
                        // the password panel.
                        root.armedId = node.modelData.id
                        root.scanNodeActivated(node.modelData.id)
                    } else {
                        root.beginSwap(node.modelData.id)
                        root.nodeActivated(node.modelData.id)
                    }
                }
            }
        }
    }
}
