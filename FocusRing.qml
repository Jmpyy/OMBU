import QtQuick

// Anillo de avance del temporizador: el tiempo en el centro y el arco violeta que se va llenando.
Item {
    id: root

    // 0 a 1
    property real progress: 0
    property string title
    property string time
    property bool active: false
    property bool dim: false

    implicitWidth: 172
    implicitHeight: 172

    Behavior on progress {
        NumberAnimation {
            duration: 300
        }
    }

    onProgressChanged: canvas.requestPaint()
    onActiveChanged: canvas.requestPaint()

    Canvas {
        id: canvas

        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2;
            const cy = height / 2;
            const r = width / 2 - 8;
            ctx.lineWidth = 7;
            ctx.lineCap = "round";
            ctx.strokeStyle = Theme.track;
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.stroke();
            if (root.progress > 0.002) {
                ctx.strokeStyle = Theme.accent;
                ctx.beginPath();
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, root.progress));
                ctx.stroke();
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.title
            color: root.active ? Theme.accent : Theme.textDim
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.time
            color: root.dim ? Theme.textDim : Theme.text
            font.pixelSize: 38
            font.weight: Font.Light
        }
    }
}
