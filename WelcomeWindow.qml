import QtQuick
import QtMultimedia
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

    readonly property bool primary: Screens.primary !== null && modelData.name === Screens.primary.name

    // La intro en video (con sonido). El fundido al irse sigue a Welcome.fade; en los monitores que no son
    // el principal queda solo el negro de fondo.
    Item {
        anchors.fill: parent
        visible: Welcome.mode === "video"
        opacity: Welcome.fade

        Rectangle {
            anchors.fill: parent
            color: "#0a0708"
        }

        VideoOutput {
            id: vo

            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            visible: win.primary
        }
    }

    Binding {
        target: Welcome.player
        property: "videoOutput"
        value: vo
        when: win.primary
    }

    // Respaldo: lluvia de código con el logo
    SaverView {
        id: view

        anchors.fill: parent
        amount: Welcome.mode === "rain" ? Welcome.fade : 0
    }

    // Línea que se escribe sola, dos filas debajo de la frase del logo
    Text {
        readonly property string shownText: Welcome.line.substring(0, Welcome.typed)

        x: Math.round((parent.width - Welcome.line.length * view.cw) / 2)
        y: view.gridY + (Saver.tagRow + 2) * view.lh
        visible: Welcome.mode === "rain"
        opacity: Welcome.fade
        text: shownText + (Welcome.typed < Welcome.line.length || cursor.on ? "▌" : " ")
        color: view.brightColor
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
