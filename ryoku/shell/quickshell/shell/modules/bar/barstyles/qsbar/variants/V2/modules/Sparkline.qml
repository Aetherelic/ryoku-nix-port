import QtQuick

// A live usage sparkline for the telemetry panels: it samples `value` into a
// ring buffer while `active` and draws a filled line graph, newest sample on
// the right. Sampling stops the instant the owning panel closes (active=false
// clears the buffer and halts the timer), so a hidden panel costs nothing --
// the same hidden-surface discipline the music clock uses (services/Music.qml).
Canvas {
    id: spark
    property var root
    property real value: 0
    property real max: 100
    property int samples: 60
    property int intervalMs: 1000
    property bool active: false
    property color lineColor: root ? root.seal : "#c4746e"
    property real fillOpacity: 0.14

    property var _buf: []

    height: 40
    onActiveChanged: if (!active) { _buf = []; requestPaint() }

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        var n = _buf.length
        if (n < 2)
            return
        var dx = width / Math.max(1, samples - 1)
        var x0 = width - (n - 1) * dx
        ctx.beginPath()
        for (var i = 0; i < n; i++) {
            var frac = Math.max(0, Math.min(1, _buf[i] / spark.max))
            var x = x0 + i * dx
            var y = height - 1 - frac * (height - 2)
            if (i === 0)
                ctx.moveTo(x, y)
            else
                ctx.lineTo(x, y)
        }
        ctx.strokeStyle = spark.lineColor
        ctx.lineWidth = 1.5
        ctx.stroke()
        ctx.lineTo(x0 + (n - 1) * dx, height)
        ctx.lineTo(x0, height)
        ctx.closePath()
        ctx.fillStyle = Qt.rgba(spark.lineColor.r, spark.lineColor.g, spark.lineColor.b, spark.fillOpacity)
        ctx.fill()
    }

    Timer {
        interval: spark.intervalMs
        running: spark.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            spark._buf.push(spark.value)
            if (spark._buf.length > spark.samples)
                spark._buf.shift()
            spark.requestPaint()
        }
    }
}
