import QtQuick
import QtQuick.Layouts

// Línea de tiempo de un reproductor MPRIS: transcurrido, barra y duración. Se arrastra para adelantar o
// atrasar (mientras se arrastra se ve adónde va y salta al soltar). La usan MediaCard y MusicMenu.
RowLayout {
    id: root

    property var player: null
    property int barHeight: 4
    property int fontSize: 10

    // Solo si el reproductor dice cuánto dura y deja saltar (un directo no)
    readonly property bool available: (player?.lengthSupported ?? false) && (player?.length ?? 0) > 0 && (player?.canSeek ?? false)
    readonly property real length: player?.length ?? 0
    readonly property real shown: seek.pressed ? seek.target : (player?.position ?? 0)

    function clock(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    visible: available
    spacing: 8

    // Quickshell no actualiza la posición solo: se la pide una vez por segundo mientras suena
    Timer {
        interval: 1000
        repeat: true
        running: root.visible && (root.player?.isPlaying ?? false)
        onTriggered: root.player.positionChanged()
    }

    Text {
        text: root.clock(root.shown)
        color: Theme.textDim
        font.pixelSize: root.fontSize
        font.features: {
            "tnum": 1
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.barHeight + 10

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: seek.pressed || seek.containsMouse ? root.barHeight + 2 : root.barHeight
            radius: height / 2
            color: Theme.track

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.shown / Math.max(1, root.length)))
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }
        }

        MouseArea {
            id: seek

            property real target: 0

            function at(x: real): real {
                return Math.max(0, Math.min(1, x / width)) * root.length;
            }

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => target = at(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    target = at(mouse.x);
            }
            onReleased: {
                if (root.player?.canSeek)
                    root.player.position = target;
            }
        }
    }

    Text {
        text: root.clock(root.length)
        color: Theme.textDim
        font.pixelSize: root.fontSize
        font.features: {
            "tnum": 1
        }
    }
}
