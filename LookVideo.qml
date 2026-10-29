import QtQuick
import QtMultimedia

// Video o audio de la vista rápida (Look). Arranca solo; un clic pausa o sigue. Va en su propio archivo
// para que QtMultimedia se cargue solo cuando hace falta.
Item {
    id: root

    property string source: ""
    property bool audioOnly: false

    MediaPlayer {
        id: player

        source: root.source
        audioOutput: AudioOutput {}
        videoOutput: video
        // El Loader de QuickLook le pasa el archivo después de crearlo: arranca recién cuando lo tiene
        onSourceChanged: if (String(source) !== "")
            play()
    }

    VideoOutput {
        id: video

        anchors.fill: parent
        anchors.bottomMargin: 34
        visible: !root.audioOnly
    }

    MIcon {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -17
        visible: root.audioOnly
        name: "music_note"
        color: Theme.textDim
        font.pixelSize: 96
    }

    MouseArea {
        anchors.fill: video
        onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()
    }

    // Barra de progreso neutra (como los sliders de ombu); un clic salta a ese punto
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 22

        MIcon {
            id: playIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            name: player.playbackState === MediaPlayer.PlayingState ? "pause" : "play_arrow"
            font.pixelSize: Theme.iconMd
        }

        Rectangle {
            id: track

            anchors.left: playIcon.right
            anchors.leftMargin: 10
            anchors.right: time.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            radius: 2
            color: Theme.track

            Rectangle {
                width: player.duration > 0 ? parent.width * player.position / player.duration : 0
                height: parent.height
                radius: 2
                color: Theme.text
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                onClicked: mouse => {
                    if (player.duration > 0)
                        player.position = player.duration * Math.max(0, Math.min(1, mouse.x / track.width));
                }
            }
        }

        Text {
            id: time

            function fmt(ms: real): string {
                const s = Math.floor(ms / 1000);
                return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
            }

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: fmt(player.position) + " / " + fmt(player.duration)
            color: Theme.textDim
            font.pixelSize: Theme.fontCaption
        }
    }
}
