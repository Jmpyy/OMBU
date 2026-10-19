pragma Singleton

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io

// Bienvenida al iniciar la sesión: una capa a pantalla completa que reproduce la intro de ombu
// (~/.local/share/ombu/intro.mp4, con sonido: telaraña, «ombu» y la firma) y, al irse, la barra baja
// desde el borde del monitor. Dura 4 segundos y un clic la salta. Si el video no está o no se puede
// reproducir, se usa la animación de antes: lluvia de código que descifra el logo y una línea que se
// escribe sola.
//
// Solo se muestra una vez por sesión: la primera vez que ombu arranca deja una marca en la
// carpeta de ejecución (que se borra al cerrar sesión), así que recargar el shell no la repite.
Singleton {
    id: root

    // La bienvenida está en curso (la barra espera escondida)
    property bool playing: false
    // Las ventanas existen (incluye el desvanecimiento final)
    property bool shown: false
    property real fade: 0
    property int fadeMs: 0
    // «video» (la intro) o «rain» (la animación de código, de respaldo)
    property string mode: "video"
    readonly property string videoPath: (Quickshell.env("HOME") ?? "") + "/.local/share/ombu/intro.mp4"
    property alias player: player
    // Línea que se escribe y cuántos caracteres van
    property string line: ""
    // Cuántos caracteres van escritos: sigue el reloj de la animación, no el del sistema
    readonly property int typed: Saver.welcome ? Math.min(line.length, Math.max(0, Math.floor((Saver.clock - 2.4) / 0.04))) : 0

    // Si el greeter ya pasó la intro antes de la contraseña (lo marca su instalador), acá no se repite.
    // `force` (el comando `welcome play`) la reproduce igual, para probar.
    function play(force): void {
        if (shown || Ui.locked)
            return;
        if (force !== true && (loginIntro.text() ?? "").trim() !== "")
            return;
        mode = "video";
        fadeMs = 0;
        fade = 1;
        shown = true;
        playing = true;
        player.source = "file://" + videoPath;
        player.play();
        // Respaldo por si el video no llegara a avanzar
        finish.interval = 7000;
        finish.restart();
    }

    // El video no está o no se pudo reproducir: la animación de código de siempre
    function fallbackToRain(): void {
        if (mode !== "video" || !playing)
            return;
        mode = "rain";
        player.stop();
        Saver.beginWelcome();
        line = (Theme.comic ? "¡THWIP! · " : "") + (Quickshell.env("USER") ?? "") + "@ombu · sesión iniciada · " + Qt.formatTime(new Date(), "HH:mm");
        finish.interval = 12000;
        finish.restart();
    }

    // Termina: la barra baja y la capa se desvanece
    function finishNow(): void {
        if (!playing)
            return;
        finish.stop();
        playing = false;
        fadeMs = 800;
        fade = 0;
        hide.restart();
    }

    Behavior on fade {
        NumberAnimation {
            duration: root.fadeMs
            easing.type: Easing.InOutQuad
        }
    }

    MediaPlayer {
        id: player

        audioOutput: AudioOutput {
            volume: 0.85
        }
        onErrorOccurred: (error, errorString) => {
            console.log("BIENVENIDA: el video falló (" + errorString + "); se usa la animación de código");
            root.fallbackToRain();
        }
        // El obturador del final deja negro a los 3,7 s: ahí empieza el desvanecimiento hacia el escritorio
        onPositionChanged: pos => {
            if (root.mode === "video" && pos >= 3700)
                root.finishNow();
        }
        onPlaybackStateChanged: if (root.mode === "video" && playbackState === MediaPlayer.StoppedState && root.playing)
            root.finishNow()
    }

    FileView {
        id: loginIntro

        path: (Quickshell.env("HOME") ?? "") + "/.local/share/ombu/intro-en-login"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: marker

        path: (Quickshell.env("XDG_RUNTIME_DIR") ?? "/tmp") + "/ombu-welcome-done"
        blockLoading: true
        printErrors: false
    }

    Connections {
        target: Saver

        function onWelcomeDone(): void {
            root.finishNow();
        }
    }

    Timer {
        id: finish

        interval: 12000
        onTriggered: root.finishNow()
    }

    Timer {
        id: hide

        interval: 900
        onTriggered: {
            root.shown = false;
            player.stop();
            if (root.mode === "rain")
                Saver.endWelcome();
        }
    }

    Component.onCompleted: {
        // text() lee el archivo en el momento; "loaded" todavía no es fiable a esta altura
        if (marker.text().trim() !== "")
            return;
        Quickshell.execDetached(["sh", "-c", "echo 1 > \"$1\"", "sh", marker.path]);
        play();
    }
}
