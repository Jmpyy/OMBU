import QtQuick
import Quickshell
import Quickshell.Hyprland

// Base de los menús que cuelgan de la barra: se deslizan desde ella y se
// funden con su silueta. El contenido se declara como hijo.
PopupWindow {
    id: root

    required property var barWindow
    required property Item anchorItem
    property bool open: false
    // Tamaño del cuerpo (sin contar la franja de esquinas cóncavas de arriba)
    property real bodyWidth: 320
    property real bodyHeight: 120
    // true = centrado bajo el botón; false = borde derecho alineado con el botón
    property bool centered: false

    default property alias content: body.data

    signal dismissed

    readonly property real fullHeight: Theme.fillet + bodyHeight

    // 0 = escondido dentro de la barra, 1 = desplegado
    property real p: open ? 1 : 0

    Behavior on p {
        NumberAnimation {
            duration: Theme.popupDuration
            easing.type: Easing.OutCubic
        }
    }

    function place(): void {
        if (centered) {
            const mid = anchorItem.mapToItem(barWindow.contentItem, anchorItem.width / 2, 0);
            anchor.rect = Qt.rect(mid.x, Theme.barHeight, 1, 1);
            return;
        }
        const pos = anchorItem.mapToItem(barWindow.contentItem, anchorItem.width, 0);
        // El borde derecho del cuerpo queda alineado con el borde derecho del botón
        anchor.rect = Qt.rect(pos.x + Theme.fillet, Theme.barHeight, 1, 1);
    }

    onOpenChanged: if (open)
        place()

    visible: p > 0.001
    color: "transparent"
    implicitWidth: bodyWidth + 2 * Theme.fillet
    implicitHeight: fullHeight
    anchor.window: barWindow
    anchor.edges: centered ? Edges.Bottom : (Edges.Bottom | Edges.Right)
    anchor.gravity: centered ? Edges.Bottom : (Edges.Bottom | Edges.Left)

    HyprlandFocusGrab {
        active: root.open
        windows: [root]
        onCleared: root.dismissed()
    }

    Item {
        anchors.fill: parent
        clip: true

        Item {
            width: parent.width
            height: parent.height
            y: -(1 - root.p) * height
            opacity: root.p

            DropShape {
                panelWidth: root.bodyWidth
                panelHeight: root.fullHeight
            }

            Item {
                id: body

                x: Theme.fillet
                y: Theme.fillet
                width: root.bodyWidth
                height: root.bodyHeight
            }
        }
    }
}
