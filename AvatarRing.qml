import QtQuick
import QtQuick.Shapes

// Avatar con un anillo que avanza con los segundos (se pone rojo si hay un error).
Item {
    id: root

    property string letter
    property bool alert: false

    // Grados recorridos por el anillo en el minuto actual
    property real sweep: 0
    property bool animate: true
    property int lastSecond: 0

    implicitWidth: 100
    implicitHeight: 100

    Behavior on sweep {
        enabled: root.animate

        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Theme.ease
        }
    }

    // Al empezar un minuto nuevo el anillo se reinicia sin recorrerse hacia atrás
    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: {
            const s = new Date().getSeconds();
            root.animate = s >= root.lastSecond;
            root.lastSecond = s;
            root.sweep = (s + 1) * 6;
            Qt.callLater(() => root.animate = true);
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(1, 1, 1, 0.1)
            strokeWidth: 3
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - 2
                radiusY: root.height / 2 - 2
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.alert ? Theme.danger : Theme.accent
            strokeWidth: 3
            capStyle: ShapePath.RoundCap

            Behavior on strokeColor {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - 2
                radiusY: root.height / 2 - 2
                startAngle: -90
                sweepAngle: root.sweep
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.width - 16
        height: width
        radius: width / 2
        color: root.alert ? Theme.danger : Theme.accent

        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.letter
            color: Theme.accentText
            font.pixelSize: 36
            font.weight: Font.DemiBold
        }
    }
}
