import QtQuick
import Quickshell.Wayland

// Bloqueo REAL de la sesión (protocolo ext-session-lock). Mientras esté activo, el
// compositor no muestra nada más que estas superficies.
WlSessionLock {
    id: lock

    locked: Ui.locked && !Ui.lockPreview

    WlSessionLockSurface {
        color: Theme.bg

        LockScreen {
            anchors.fill: parent
            preview: false
        }
    }
}
