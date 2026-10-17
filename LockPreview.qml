import QtQuick
import Quickshell
import Quickshell.Wayland

// Vista previa del bloqueo: una ventana común a pantalla completa. No bloquea la sesión
// y se cierra con Esc, así que sirve para probar el diseño y la contraseña sin riesgo.
PanelWindow {
    id: win

    required property var modelData

    screen: modelData
    visible: Ui.locked && Ui.lockPreview
    color: Theme.bg
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nuestro-lockpreview"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    LockScreen {
        anchors.fill: parent
        preview: true
    }
}
