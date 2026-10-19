import QtQuick
import Quickshell
import Quickshell.Wayland

// Fondo de pantalla: una capa Background por monitor.
PanelWindow {
    id: win

    required property var modelData

    screen: modelData
    color: Theme.bg
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "ombu-wallpaper"

    Image {
        anchors.fill: parent
        source: "file://" + Walls.shown
        asynchronous: true
        smooth: true
        // La imagen es ultrawide: se recorta para llenar el monitor sin deformarse
        fillMode: Image.PreserveAspectCrop
        // Se decodifica al tamaño del monitor, no al de la imagen original
        sourceSize: Qt.size(win.modelData.width, win.modelData.height)
        opacity: status === Image.Ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }
    }

    // Trama de puntos Ben-Day de imprenta retro sobre el fondo
    Image {
        anchors.fill: parent
        visible: Theme.comic
        source: "assets/halftone.png"
        fillMode: Image.Tile
        opacity: 0.08
        smooth: false
    }
}
