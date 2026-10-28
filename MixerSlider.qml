import QtQuick

// Slider de volumen (0 a 1), fino y con perilla como el del menú de sonido de macOS; relleno neutro.
// Emite moved() mientras se arrastra o con la rueda.
Item {
    id: root

    property real value: 0
    property bool muted: false

    signal moved(real value)

    function clamp(v: real): real {
        return Math.max(0, Math.min(1, v));
    }

    implicitHeight: 22

    Rectangle {
        id: track

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        radius: 2
        color: Theme.track

        Rectangle {
            width: track.width * root.clamp(root.value)
            height: parent.height
            radius: parent.radius
            color: root.muted ? Theme.textDim : Theme.text
        }
    }

    Rectangle {
        x: (root.width - width) * root.clamp(root.value)
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: 7
        color: root.muted ? Theme.textDim : Theme.text
        scale: area.pressed ? 1.15 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.animFast
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.moved(root.clamp(mouse.x / width))
        onPositionChanged: mouse => {
            if (pressed)
                root.moved(root.clamp(mouse.x / width));
        }
        onWheel: wheel => root.moved(root.clamp(root.value + (wheel.angleDelta.y > 0 ? 0.04 : -0.04)))
    }
}
