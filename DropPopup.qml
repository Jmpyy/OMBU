import QtQuick
import Quickshell
import Quickshell.Hyprland

// Base de los menús que cuelgan de la barra: se funden con su silueta y crecen desde el
// botón que los abrió. El contenido se declara como hijo.
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

    // La ventana del menú tarda ~150 ms en crearse y dibujar su primer cuadro. Si la animación
    // arrancara al pedir el menú, para cuando la ventana se ve ya habría pasado casi entera y
    // se vería como un salto. Por eso espera a que la ventana haya dibujado un primer cuadro.
    property bool ready: false

    // 0 = recogido en el botón, 1 = desplegado
    property real p: (open && ready) ? 1 : 0

    // Punto de la barra del que crece el menú (el centro del botón, sobre el borde de arriba)
    readonly property real originX: centered ? implicitWidth / 2 : implicitWidth - Theme.fillet - anchorItem.width / 2

    Behavior on p {
        NumberAnimation {
            duration: Theme.popupDuration
            easing.type: Easing.OutCubic
        }
    }

    // El menú se ancla al borde inferior de un rectángulo de 1 px, y se sube para que quede
    // 1 px montado sobre la barra: sin esto queda un filo de 1 px entre ambos que deja ver el
    // fondo de pantalla y hace que se vean como dos piezas separadas.
    readonly property int seamFix: 2

    function place(): void {
        const y = Theme.barHeight - seamFix;
        if (centered) {
            const mid = anchorItem.mapToItem(barWindow.contentItem, anchorItem.width / 2, 0);
            anchor.rect = Qt.rect(mid.x, y, 1, 1);
            return;
        }
        const pos = anchorItem.mapToItem(barWindow.contentItem, anchorItem.width, 0);
        // El borde derecho del cuerpo queda alineado con el borde derecho del botón
        anchor.rect = Qt.rect(pos.x + Theme.fillet, y, 1, 1);
    }

    onOpenChanged: if (open)
        place()

    visible: open || p > 0.001
    onVisibleChanged: if (!visible)
        ready = false

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

    // Avisa cuando la ventana ya dibujó su primer cuadro (ahí arranca la animación)
    Item {
        id: frameWatcher

        readonly property var win: Window.window

        Connections {
            target: frameWatcher.win
            enabled: root.visible && !root.ready

            function onFrameSwapped(): void {
                root.ready = true;
            }
        }

        // Respaldo por si la señal no llegara: no se deja el menú invisible
        Timer {
            interval: 450
            running: root.visible && !root.ready
            onTriggered: root.ready = true
        }
    }

    // La caja crece desde el botón (se achica hacia su borde de arriba, que sigue pegado a la
    // barra) y el contenido aparece un poco después. Al cerrar hace el camino inverso.
    Item {
        anchors.fill: parent

        Item {
            width: parent.width
            height: parent.height
            opacity: Math.min(1, root.p * 1.8)
            transform: Scale {
                origin.x: root.originX
                origin.y: 0
                xScale: 0.88 + 0.12 * root.p
                yScale: 0.62 + 0.38 * root.p
            }

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
                opacity: Math.max(0, (root.p - 0.3) / 0.7)
            }
        }
    }
}
