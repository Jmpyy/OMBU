pragma Singleton

import QtQuick
import Quickshell

// Estado compartido de la interfaz.
Singleton {
    property bool barShown: true
    property bool powerOpen: false
    property bool launcherOpen: false
    // Texto con el que se abre el launcher (para atajos que lo precargan)
    property string launcherPrefill: ""
    // Menú desplegado de la barra, con formato "tipo@monitor" (ej. "mixer@HDMI-A-1"); "" = ninguno
    property string popup: ""
}
