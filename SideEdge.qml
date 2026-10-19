import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Borde sensible del lado izquierdo del monitor principal: pegar el mouse ahí un instante abre el
// panel lateral. Es una franja de 2 px en la capa «top», así que una ventana en pantalla completa
// la tapa, y no se abre en el escritorio de juegos. El instante de espera evita que se abra de
// casualidad al arrastrar ventanas.
PanelWindow {
    id: win

    required property var modelData

    // Escritorios donde no se abre con el mouse (el de juegos)
    readonly property bool blocked: Hyprland.focusedWorkspace?.name === "gaming"

    screen: modelData
    color: "transparent"
    anchors {
        left: true
        top: true
        bottom: true
    }
    implicitWidth: 2
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "ombu-edge"
    visible: !Ui.sideOpen

    Timer {
        id: dwell

        interval: 300
        onTriggered: if (hover.hovered && !win.blocked)
            Ui.sideOpen = true
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered && !win.blocked)
                dwell.restart();
            else
                dwell.stop();
        }
    }
}
