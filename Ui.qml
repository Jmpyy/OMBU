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
    property bool keysOpen: false
    property bool sysMenuOpen: false
    property bool wallMenuOpen: false
    // Contador que pide abrir o cerrar la vista previa del launcher (ipc call launcher preview)
    property int launcherPreviewTick: 0
    // Sección por la que abre el menú del sistema, por ejemplo "Estilo>Tema" (vacío = el principio)
    property string sysMenuStart: ""
    // Texto con el que se abre el launcher (para atajos que lo precargan)
    property string launcherPrefill: ""
    // Menú desplegado de la barra, con formato "tipo@monitor" (ej. "mixer@HDMI-A-1"); "" = ninguno
    property string popup: ""
}
