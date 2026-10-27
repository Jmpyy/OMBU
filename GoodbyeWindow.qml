import QtQuick
import Quickshell
import Quickshell.Wayland

// La despedida sobre el escritorio (ver Goodbye): existe solo mientras dura (LazyLoader en shell.qml).
// Toma el teclado para que nada de abajo reciba teclas mientras se apaga.
PanelWindow {
    id: win

    required property var modelData

    screen: modelData
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ombu-goodbye"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    GoodbyeView {
        id: view

        anchors.fill: parent
        armed: false
    }

    FirstFrame {
        onReady: view.armed = true
    }
}
