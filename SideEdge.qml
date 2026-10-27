import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Borde sensible del lado izquierdo del monitor principal: pegar el mouse ahí un instante abre el
// panel lateral. Es una franja de 2 px en la capa «top», así que una ventana en pantalla completa
// la tapa, y no se abre en el escritorio de juegos. Hay que quedarse quieto ahí medio segundo: deslizar
// el mouse por el borde (las pestañas de Zen, arrastrar ventanas) no lo abre.
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

    // Altura donde empezó la espera: si el mouse se aleja más de `slack` px, empieza de nuevo
    property real anchorY: 0
    readonly property real slack: 40

    Timer {
        id: dwell

        interval: 500
        onTriggered: if (hover.hovered && !win.blocked)
            Ui.sideOpen = true
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered && !win.blocked) {
                win.anchorY = point.position.y;
                dwell.restart();
            } else {
                dwell.stop();
            }
        }
        onPointChanged: if (hovered && Math.abs(point.position.y - win.anchorY) > win.slack) {
            win.anchorY = point.position.y;
            dwell.restart();
        }
    }
}
