pragma Singleton

import QtQuick
import Quickshell

// Estado compartido de la interfaz.
Singleton {
    property bool barShown: true
    property bool powerOpen: false
    // Bloqueo de pantalla. En modo vista previa es una ventana común (se cierra con Esc),
    // no un bloqueo real de la sesión.
    property bool locked: false
    property bool lockPreview: false
    property bool launcherOpen: false
    // Historial del portapapeles abierto
    property bool clipOpen: false
    // Texto con el que se abre el launcher (para atajos que lo precargan)
    property string launcherPrefill: ""
    // Menú desplegado de la barra, con formato "tipo@monitor" (ej. "mixer@HDMI-A-1"); "" = ninguno
    property string popup: ""
}
