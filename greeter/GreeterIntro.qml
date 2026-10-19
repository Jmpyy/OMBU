import QtQuick
import QtMultimedia
import Quickshell

// La intro de ombu (video con sonido) por encima del login. El formulario ya está listo debajo: apenas se
// escribe una tecla, se hace clic o termina el video (el último tramo es negro), se desvanece y queda la
// contraseña. Si el video no está o no se puede reproducir, se salta sola en el acto.
Item {
    id: root

    anchors.fill: parent
    opacity: IntroState.playing ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation {
            duration: 450
            easing.type: Easing.InOutQuad
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#0a0708"
    }

    VideoOutput {
        id: vo

        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

    MediaPlayer {
        id: player

        source: Qt.resolvedUrl("intro.mp4")
        videoOutput: vo
        audioOutput: AudioOutput {
            volume: 0.85
        }
        onErrorOccurred: (error, errorString) => {
            console.log("INTRO: no se pudo reproducir (" + errorString + ")");
            IntroState.skip();
        }
        // El obturador del final deja negro a los 3,7 s: ahí empieza el desvanecimiento hacia el login
        onPositionChanged: pos => {
            if (pos >= 3700)
                IntroState.skip();
        }
        onPlaybackStateChanged: if (playbackState === MediaPlayer.StoppedState && position > 0)
            IntroState.skip()
    }

    // Termina de desvanecerse: se suelta el video
    onVisibleChanged: if (!visible)
        player.stop()

    TapHandler {
        onTapped: IntroState.skip()
    }

    Component.onCompleted: player.play()
}
