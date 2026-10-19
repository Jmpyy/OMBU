pragma Singleton

import QtQuick
import Quickshell

// Estado de la intro de ombu en el login: suena al aparecer la pantalla y se salta con cualquier tecla,
// un clic, al terminar el video o si falla (el campo de contraseña nunca queda esperando al video).
Singleton {
    property bool playing: true

    function skip(): void {
        playing = false;
    }
}
