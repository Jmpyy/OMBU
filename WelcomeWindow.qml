import QtQuick
import Quickshell
import Quickshell.Wayland

// Capa de bienvenida (ver Welcome): una por monitor, por encima de todo.
PanelWindow {
    id: win

    required property var modelData

    screen: modelData
    visible: Welcome.shown
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ombu-welcome"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    SaverView {
        id: view

        anchors.fill: parent
        amount: Welcome.fade
    }

    // Línea que se escribe sola, dos filas debajo de la frase del logo
    Text {
        readonly property string shownText: Welcome.line.substring(0, Welcome.typed)

        x: Math.round((parent.width - Welcome.line.length * view.cw) / 2)
        y: view.gridY + (Saver.tagRow + 2) * view.lh
        opacity: Welcome.fade
        text: shownText + (Welcome.typed < Welcome.line.length || cursor.on ? "▌" : " ")
        color: "#9b87f5"
        font.family: "monospace"
        font.pixelSize: Theme.saverFontSize
        renderType: Text.QtRendering

        Timer {
            id: cursor

            property bool on: true

            interval: 500
            repeat: true
            running: win.visible
            onTriggered: on = !on
        }
    }

    // Un clic salta la bienvenida
    TapHandler {
        onTapped: Welcome.finishNow()
    }
}
