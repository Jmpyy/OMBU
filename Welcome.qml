pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Bienvenida al iniciar la sesión: una capa a pantalla completa con la lluvia de código
// que descifra el logo, una línea que se escribe sola y, al irse, la barra baja desde el
// borde del monitor. Dura unos 3 segundos y un clic la salta.
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
    // Línea que se escribe y cuántos caracteres van
    property string line: ""
    // Cuántos caracteres van escritos: sigue el reloj de la animación, no el del sistema
    readonly property int typed: Saver.welcome ? Math.min(line.length, Math.max(0, Math.floor((Saver.clock - 2.4) / 0.04))) : 0

    function play(): void {
        if (shown || Ui.locked)
            return;
        Saver.beginWelcome();
        line = (Quickshell.env("USER") ?? "") + "@ombu · sesión iniciada · " + Qt.formatTime(new Date(), "HH:mm");
        fadeMs = 0;
        fade = 1;
        shown = true;
        playing = true;
        // Respaldo por si la animación no llegara a avanzar
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
